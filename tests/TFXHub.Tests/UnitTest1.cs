using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using HostDbContext = TFXHub.Host.Models.TFXHubDbContext;

namespace TFXHub.Tests;

public class HostApiTests
{
    [Fact]
    public async Task Root_ReturnsOperationalMessage()
    {
        await using var factory = CreateFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/");
        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<MessageResponse>();

        Assert.NotNull(payload);
        Assert.Equal("TFX Hub API Host is operational.", payload!.message);
    }

    [Fact]
    public async Task Health_ReturnsHealthy()
    {
        await using var factory = CreateFactory();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/health");
        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<HealthResponse>();

        Assert.NotNull(payload);
        Assert.Equal("Healthy", payload!.status);
    }

    [Fact]
    public async Task Users_Crud_Cycle_Works()
    {
        await using var factory = CreateFactory();
        using var client = factory.CreateClient();

        var createResponse = await client.PostAsJsonAsync("/api/users", new UserProfileDto
        {
            Name = "Integration Test User",
            Role = "Client"
        });
        createResponse.EnsureSuccessStatusCode();

        var created = await createResponse.Content.ReadFromJsonAsync<UserProfileDto>();
        Assert.NotNull(created);
        Assert.True(created!.Id > 0);

        var getResponse = await client.GetAsync($"/api/users/{created.Id}");
        getResponse.EnsureSuccessStatusCode();
        var fetched = await getResponse.Content.ReadFromJsonAsync<UserProfileDto>();
        Assert.NotNull(fetched);
        Assert.Equal("Integration Test User", fetched!.Name);

        created.Name = "Updated Integration User";
        created.Role = "Host";
        var updateResponse = await client.PutAsJsonAsync($"/api/users/{created.Id}", created);
        updateResponse.EnsureSuccessStatusCode();

        var updated = await updateResponse.Content.ReadFromJsonAsync<UserProfileDto>();
        Assert.NotNull(updated);
        Assert.Equal("Updated Integration User", updated!.Name);
        Assert.Equal("Host", updated.Role);

        var deleteResponse = await client.DeleteAsync($"/api/users/{created.Id}");
        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

        var missingResponse = await client.GetAsync($"/api/users/{created.Id}");
        Assert.Equal(HttpStatusCode.NotFound, missingResponse.StatusCode);
    }

    private static WebApplicationFactory<Program> CreateFactory()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();

        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Development");
                builder.ConfigureServices(services =>
                {
                    services.RemoveAll(typeof(DbContextOptions<HostDbContext>));
                    services.RemoveAll(typeof(HostDbContext));
                    services.AddSingleton(connection);
                    services.AddDbContext<HostDbContext>(options => options.UseSqlite(connection));
                });
            });
    }

    private sealed class MessageResponse
    {
        public string message { get; set; } = string.Empty;
    }

    private sealed class HealthResponse
    {
        public string status { get; set; } = string.Empty;
    }

    private sealed class UserProfileDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
    }
}
