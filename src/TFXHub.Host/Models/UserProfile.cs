namespace TFXHub.Host.Models;

public class UserProfile

{

    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Role { get; set; } = string.Empty; // Host, Agent, Client

}