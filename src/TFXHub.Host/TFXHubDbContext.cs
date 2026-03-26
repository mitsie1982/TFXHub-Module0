using Microsoft.EntityFrameworkCore;
using TFXHub.Host.Models;

namespace TFXHub.Host;

public class TFXHubDbContext : DbContext
{
    public TFXHubDbContext(DbContextOptions<TFXHubDbContext> options)
        : base(options)
    {
    }

    public DbSet<UserProfile> UserProfiles { get; set; } = null!;
}
