using Microsoft.EntityFrameworkCore;

namespace TFXHub.Host.Models;

public class TFXHubDbContext : DbContext

{

    public TFXHubDbContext(DbContextOptions<TFXHubDbContext> options) : base(options) { }

    public DbSet<UserProfile> UserProfiles { get; set; }

}