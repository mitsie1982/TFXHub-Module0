using System;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using Serilog;
using OpenTelemetry.Trace;
using OpenTelemetry.Resources;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using TFXHub.Host.Models;

var builder = WebApplication.CreateBuilder(args);

// Load configuration and environment
var configuration = builder.Configuration;
var env = builder.Environment;

// Serilog configuration
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/tfxhub-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// EF Core - SQLite example; replace with your production DB as needed
var connectionString = configuration.GetConnectionString("DefaultConnection") 
                       ?? "Data Source=tfxhub.db";
builder.Services.AddDbContext<TFXHubDbContext>(options =>
    options.UseSqlite(connectionString));

// Health checks
builder.Services.AddHealthChecks();

// CORS - allow from configured origins or all for dev
var allowedOrigins = configuration.GetValue<string>("AllowedOrigins") ?? "*";
builder.Services.AddCors(options =>
{
    options.AddPolicy("DefaultCors", policy =>
    {
        if (allowedOrigins == "*")
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        else
            policy.WithOrigins(allowedOrigins.Split(';')).AllowAnyHeader().AllowAnyMethod();
    });
});

// OpenTelemetry tracing
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
    {
        tracerProviderBuilder
            .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("TFXHub.Host"))
            .AddAspNetCoreInstrumentation()
            .AddConsoleExporter();
    });

// Optional: configure API behavior and model validation responses
builder.Services.Configure<Microsoft.AspNetCore.Mvc.ApiBehaviorOptions>(options =>
{
    options.SuppressModelStateInvalidFilter = false;
});

var app = builder.Build();

// Apply migrations and seed DB at startup (safe for dev; gate for prod)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<TFXHubDbContext>();
    db.Database.EnsureCreated();
    
    // Seed initial data
    if (!db.UserProfiles.Any())
    {
        db.UserProfiles.AddRange(
            new UserProfile { Name = "Host User", Role = "Host" },
            new UserProfile { Name = "Agent User", Role = "Agent" },
            new UserProfile { Name = "Client User", Role = "Client" },
            new UserProfile { Name = "Extra Host", Role = "Host" },
            new UserProfile { Name = "Extra Client", Role = "Client" });
        db.SaveChanges();
    }
}

// Middleware pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// In containerized environments you may not want HTTPS redirection
var disableHttpsRedirect = configuration.GetValue<bool>("DisableHttpsRedirect", false);
if (!disableHttpsRedirect)
{
    app.UseHttpsRedirection();
}

app.UseSerilogRequestLogging();
app.UseRouting();
app.UseCors("DefaultCors");
app.UseAuthorization();

// Health endpoints
app.MapHealthChecks("/api/health", new HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        var result = System.Text.Json.JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new { name = e.Key, status = e.Value.Status.ToString() })
        });
        await context.Response.WriteAsync(result);
    }
});

app.MapGet("/api/users", async (TFXHubDbContext db) =>
    Results.Ok(await db.UserProfiles.ToListAsync()));

app.MapGet("/api/users/{id:int}", async (int id, TFXHubDbContext db) =>
{
    var user = await db.UserProfiles.FindAsync(id);
    return user is not null ? Results.Ok(user) : Results.NotFound(new { Message = "User not found" });
});

app.MapPost("/api/users", async (TFXHubDbContext db, UserProfile user) =>
{
    if (string.IsNullOrWhiteSpace(user.Name) || string.IsNullOrWhiteSpace(user.Role))
    {
        return Results.BadRequest(new { Message = "Name and Role are required." });
    }

    var normalizedRole = user.Role.Trim();
    if (!new[] { "Host", "Agent", "Client" }.Contains(normalizedRole, StringComparer.OrdinalIgnoreCase))
    {
        return Results.BadRequest(new { Message = "Role must be one of Host, Agent, Client." });
    }

    user.Role = char.ToUpper(normalizedRole[0]) + normalizedRole.Substring(1).ToLower();

    db.UserProfiles.Add(user);
    await db.SaveChangesAsync();
    return Results.Created($"/api/users/{user.Id}", user);
});

app.MapPut("/api/users/{id:int}", async (int id, TFXHubDbContext db, UserProfile updatedUser) =>
{
    if (id != updatedUser.Id && updatedUser.Id != 0)
    {
        return Results.BadRequest(new { Message = "Id in route and body must match" });
    }

    var existingUser = await db.UserProfiles.FindAsync(id);
    if (existingUser is null) return Results.NotFound(new { Message = "User not found" });

    if (string.IsNullOrWhiteSpace(updatedUser.Name) || string.IsNullOrWhiteSpace(updatedUser.Role))
    {
        return Results.BadRequest(new { Message = "Name and Role are required." });
    }

    var normalizedRole = updatedUser.Role.Trim();
    if (!new[] { "Host", "Agent", "Client" }.Contains(normalizedRole, StringComparer.OrdinalIgnoreCase))
    {
        return Results.BadRequest(new { Message = "Role must be one of Host, Agent, Client." });
    }

    existingUser.Name = updatedUser.Name.Trim();
    existingUser.Role = char.ToUpper(normalizedRole[0]) + normalizedRole.Substring(1).ToLower();

    await db.SaveChangesAsync();

    return Results.Ok(existingUser);
});

app.MapDelete("/api/users/{id:int}", async (int id, TFXHubDbContext db) =>
{
    var user = await db.UserProfiles.FindAsync(id);
    if (user is null) return Results.NotFound(new { Message = "User not found" });

    db.UserProfiles.Remove(user);
    await db.SaveChangesAsync();

    return Results.NoContent();
});

// Root endpoint
app.MapGet("/", () => Results.Ok(new { message = "TFX Hub API Host is operational." }));

// Respect ASPNETCORE_URLS or explicit HOST_URLS env var
var urls = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") 
           ?? Environment.GetEnvironmentVariable("HOST_URLS");
if (!string.IsNullOrEmpty(urls))
{
    app.Urls.Clear();
    foreach (var u in urls.Split(';', StringSplitOptions.RemoveEmptyEntries))
        app.Urls.Add(u);
}
else
{
    // Default to 0.0.0.0:5000 if no URLs specified
    app.Urls.Add("http://0.0.0.0:5000");
}

// Start the app
try
{
    Log.Information("Starting TFX Hub Host");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Host terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}