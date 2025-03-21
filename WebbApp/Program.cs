using DotNetEnv;
using MongoDB.Driver;
using FluentValidation;
using FluentValidation.AspNetCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MVC_TestApp.Controllers;
using MVC_TestApp.Models;
using MVC_TestApp.Repositories;
using MVC_TestApp.Services;
using MVC_TestApp.Storage;

// Load environment variables from .env
Env.Load();

var builder = WebApplication.CreateBuilder(args);

// Add environment variables to configuration
builder.Configuration.AddEnvironmentVariables();

// Configure logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
var logger = loggerFactory.CreateLogger("Program");

// Register common services
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<INewsletterService, NewsletterService>();
builder.Services.AddScoped<IValidator<Subscriber>, UserValidator>();
builder.Services.AddFluentValidationAutoValidation();

// Read which repository to use (default = inmemory if not specified)
string? repoType = builder.Configuration.GetValue<string>("SUBSCRIBER_REPOSITORY", "inmemory")?.ToLowerInvariant();
repoType ??= "inmemory";

if (repoType == "mongo" || repoType == "cosmos")
{
    // Get connection string from configuration
    string? connectionString = builder.Configuration.GetSection("MongoDB:ConnectionString").Value;

    logger.LogInformation("MongoDB connection string set: {IsSet}, Length: {Length}",
        !string.IsNullOrEmpty(connectionString),
        connectionString?.Length ?? 0);

    logger.LogInformation("Using MongoDB repository");
    builder.Services.AddSingleton<IMongoClient>(new MongoClient(connectionString));

    if (string.IsNullOrEmpty(connectionString))
    {
        // Fallback to environment variable or connection strings section
        connectionString = builder.Configuration.GetConnectionString("MongoDB");
    }

    if (string.IsNullOrEmpty(connectionString))
    {
        logger.LogWarning("MongoDB connection string not found. Using InMemory repository instead.");
        builder.Services.AddSingleton<ISubscriberRepository, InMemorySubscriberRepository>();
    }
    else
    {
        logger.LogInformation("Using MongoDB connection string. Length: {Length}", connectionString.Length);
        try
        {
            // Register MongoDB client and services
            builder.Services.AddSingleton<IMongoClient>(new MongoClient(connectionString));
            builder.Services.AddSingleton<IMongoDatabase>(sp =>
            {
                var client = sp.GetRequiredService<IMongoClient>();
                string dbName = builder.Configuration["MongoDB:DatabaseName"] ?? "cloudsoft";
                return client.GetDatabase(dbName);
            });

            // Register the correct repository type
            if (repoType == "mongo")
            {
                builder.Services.AddSingleton<ISubscriberRepository, MongoDbSubscriberRepository>();
                logger.LogInformation("Registered MongoDbSubscriberRepository.");
            }
            else // repoType == "cosmos"
            {
                builder.Services.AddSingleton<ISubscriberRepository, CosmosDbSubscriberRepository>();
                logger.LogInformation("Registered CosmosDbSubscriberRepository.");
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to configure MongoDB. Using InMemory repository instead.");
            builder.Services.AddSingleton<ISubscriberRepository, InMemorySubscriberRepository>();
        }
    }
}
else if (repoType == "inmemory")
{
    builder.Services.AddSingleton<ISubscriberRepository, InMemorySubscriberRepository>();
    logger.LogInformation("Registered InMemorySubscriberRepository.");
}
else
{
    logger.LogWarning($"Unknown SUBSCRIBER_REPOSITORY value '{repoType}'. Using default: InMemory.");
    builder.Services.AddSingleton<ISubscriberRepository, InMemorySubscriberRepository>();
}

// Read feature flag for image storage service from configuration.
bool useAzureStorage = builder.Configuration.GetValue<bool>("FEATUREFLAGS:USEAZURESTORAGE", false);
logger.LogInformation($"FEATUREFLAGS: USEAZURESTORAGE = {useAzureStorage}");

// If useAzureStorage is true, register AzureBlobImageService, otherwise LocalImageService.
if (useAzureStorage)
{
    logger.LogInformation("Using Azure Blob Storage for images...");
    builder.Services.AddSingleton<IImageService, AzureBlobImageService>();
}
else
{
    logger.LogInformation("Using local image storage...");
    builder.Services.AddSingleton<IImageService, LocalImageService>();
}

builder.Services.AddControllersWithViews();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();