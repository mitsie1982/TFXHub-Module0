using System;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Prometheus;
using Serilog;
using TFXHub.Host.Models;

var builder = WebApplication.CreateBuilder(args);

var configuration = builder.Configuration;

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/tfxhub-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var connectionString = configuration.GetConnectionString("DefaultConnection")
    ?? "Data Source=tfxhub.db";
builder.Services.AddDbContext<TFXHubDbContext>(options =>
    options.UseSqlite(connectionString));

builder.Services.AddHealthChecks();

var allowedOrigins = configuration.GetValue<string>("AllowedOrigins") ?? "*";
builder.Services.AddCors(options =>
{
    options.AddPolicy("DefaultCors", policy =>
    {
        if (allowedOrigins == "*")
        {
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        }
        else
        {
            policy.WithOrigins(allowedOrigins.Split(';')).AllowAnyHeader().AllowAnyMethod();
        }
    });
});

builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
    {
        tracerProviderBuilder
            .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("TFXHub.Host"))
            .AddAspNetCoreInstrumentation()
            .AddConsoleExporter();
    });

builder.Services.Configure<Microsoft.AspNetCore.Mvc.ApiBehaviorOptions>(options =>
{
    options.SuppressModelStateInvalidFilter = false;
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<TFXHubDbContext>();
    db.Database.EnsureCreated();

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

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

var disableHttpsRedirect = configuration.GetValue<bool>("DisableHttpsRedirect", false);
if (!disableHttpsRedirect)
{
    app.UseHttpsRedirection();
}

app.UseSerilogRequestLogging();
app.UseHttpMetrics();
app.UseRouting();
app.UseCors("DefaultCors");
app.UseAuthorization();

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
    if (existingUser is null)
    {
        return Results.NotFound(new { Message = "User not found" });
    }

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
    if (user is null)
    {
        return Results.NotFound(new { Message = "User not found" });
    }

    db.UserProfiles.Remove(user);
    await db.SaveChangesAsync();

    return Results.NoContent();
});

app.MapGet("/", () => Results.Ok(new { message = "TFX Hub API Host is operational." }));
app.MapMetrics("/metrics");

var urls = Environment.GetEnvironmentVariable("ASPNETCORE_URLS")
           ?? Environment.GetEnvironmentVariable("HOST_URLS");
if (!string.IsNullOrEmpty(urls))
{
    app.Urls.Clear();
    foreach (var u in urls.Split(';', StringSplitOptions.RemoveEmptyEntries))
    {
        app.Urls.Add(u);
    }
}
else
{
    app.Urls.Add("http://0.0.0.0:5000");
}

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

public partial class Program { }

