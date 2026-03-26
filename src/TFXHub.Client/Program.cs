using Serilog;
using OpenTelemetry;
using OpenTelemetry.Trace;
using System.Net.Http.Json;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/tfxhub-client-.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)
    .CreateLogger();

using var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("TFXHub.Client")
    .AddConsoleExporter()
    .Build();

var baseAddress = Environment.GetEnvironmentVariable("HOST_BASE_URL") ?? "http://localhost:5000";
var httpClient = new HttpClient { BaseAddress = new Uri(baseAddress) };

while (true)
{
    Console.WriteLine("\nChoose action:\n1. List all users\n2. Add new user\n3. Update a user\n4. Delete a user\n5. Exit");
    Console.Write("Selection: ");
    var choice = Console.ReadLine()?.Trim();

    try
    {
        switch (choice)
        {
            case "1":
                await ListUsersAsync(httpClient);
                break;
            case "2":
                await AddUserAsync(httpClient);
                break;
            case "3":
                await UpdateUserAsync(httpClient);
                break;
            case "4":
                await DeleteUserAsync(httpClient);
                break;
            case "5":
                return;
            default:
                Console.WriteLine("Invalid selection. Choose 1-5.");
                break;
        }
    }
    catch (Exception ex)
    {
        Log.Error(ex, "Client operation failed");
        Console.WriteLine($"Error: {ex.Message}");
    }
}

static async Task ListUsersAsync(HttpClient client)
{
    var users = await client.GetFromJsonAsync<List<UserProfile>>("/api/users");
    if (users is null || users.Count == 0)
    {
        Console.WriteLine("No users found.");
        return;
    }

    Console.WriteLine("Users:");
    foreach (var user in users)
    {
        Console.WriteLine($"- {user.Id}: {user.Name} ({user.Role})");
    }
}

static async Task AddUserAsync(HttpClient client)
{
    Console.Write("Name: ");
    var name = Console.ReadLine()?.Trim();
    Console.Write("Role (Host/Agent/Client): ");
    var role = Console.ReadLine()?.Trim();

    if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(role))
    {
        Console.WriteLine("Name and role are required.");
        return;
    }

    var newUser = new UserProfile { Name = name, Role = role };
    var response = await client.PostAsJsonAsync("/api/users", newUser);

    if (!response.IsSuccessStatusCode)
    {
        Console.WriteLine($"Failed to add user: {response.StatusCode}");
        var error = await response.Content.ReadAsStringAsync();
        Console.WriteLine(error);
        return;
    }

    var created = await response.Content.ReadFromJsonAsync<UserProfile>();
    Console.WriteLine($"Created user: {created?.Id} {created?.Name} ({created?.Role})");
}

static async Task UpdateUserAsync(HttpClient client)
{
    Console.Write("User ID to update: ");
    if (!int.TryParse(Console.ReadLine(), out var id))
    {
        Console.WriteLine("Invalid ID.");
        return;
    }

    var existing = await client.GetAsync($"/api/users/{id}");
    if (!existing.IsSuccessStatusCode)
    {
        Console.WriteLine($"User not found: {id}");
        return;
    }

    var user = await existing.Content.ReadFromJsonAsync<UserProfile>();
    if (user is null)
    {
        Console.WriteLine("Unable to deserialize user.");
        return;
    }

    Console.Write($"Name ({user.Name}): ");
    var name = Console.ReadLine()?.Trim();
    Console.Write($"Role ({user.Role}): ");
    var role = Console.ReadLine()?.Trim();

    if (!string.IsNullOrWhiteSpace(name)) user.Name = name;
    if (!string.IsNullOrWhiteSpace(role)) user.Role = role;

    var response = await client.PutAsJsonAsync($"/api/users/{id}", user);
    if (!response.IsSuccessStatusCode)
    {
        Console.WriteLine($"Update failed: {response.StatusCode}");
        var err = await response.Content.ReadAsStringAsync();
        Console.WriteLine(err);
        return;
    }

    var updated = await response.Content.ReadFromJsonAsync<UserProfile>();
    Console.WriteLine($"Updated user: {updated?.Id} {updated?.Name} ({updated?.Role})");
}

static async Task DeleteUserAsync(HttpClient client)
{
    Console.Write("User ID to delete: ");
    if (!int.TryParse(Console.ReadLine(), out var id))
    {
        Console.WriteLine("Invalid ID.");
        return;
    }

    var response = await client.DeleteAsync($"/api/users/{id}");
    if (response.IsSuccessStatusCode)
    {
        Console.WriteLine("User deleted.");
    }
    else
    {
        Console.WriteLine($"Delete failed: {response.StatusCode}");
        var err = await response.Content.ReadAsStringAsync();
        Console.WriteLine(err);
    }
}

// Local UserProfile model for client-side use
class UserProfile
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
}