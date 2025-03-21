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

logger.LogInformation($"Repository type: {repoType}");

if (repoType == "mongo" || repoType == "cosmos")
{
    // First attempt to get connection string from configuration - do this ONCE
    string? connectionString = builder.Configuration.GetSection("MongoDB:ConnectionString").Value;

    // Log connection string status (for debugging)
    logger.LogInformation("MongoDB connection string from config: {IsSet}, Length: {Length}",
        !string.IsNullOrEmpty(connectionString),
        connectionString?.Length ?? 0);

    // If empty, try fallback sources
    if (string.IsNullOrEmpty(connectionString))
    {
        // Try connection strings section
        connectionString = builder.Configuration.GetConnectionString("MongoDB");

        // Log fallback attempt
        if (!string.IsNullOrEmpty(connectionString))
            logger.LogInformation("Found MongoDB connection string in ConnectionStrings section");
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
            logger.LogInformation("Configuring MongoDB client with connection string");
            // Register MongoDB client and services
            builder.Services.AddSingleton<IMongoClient>(provider => {
                logger.LogInformation("Creating MongoDB client with connection string");
                return new MongoClient(connectionString);
            });

            builder.Services.AddSingleton<IMongoDatabase>(sp =>
            {
                var client = sp.GetRequiredService<IMongoClient>();
                string dbName = builder.Configuration["MongoDB:DatabaseName"] ?? "cloudsoft";
                logger.LogInformation("Getting MongoDB database: {DbName}", dbName);
                return client.GetDatabase(dbName);
            });

            // Register the correct repository type
            if (repoType == "mongo")
            {
                builder.Services.AddSingleton<ISubscriberRepository, MongoDbSubscriberRepository>();
                logger.LogInformation("Registered MongoDbSubscriberRepository");
            }
            else // repoType == "cosmos"
            {
                builder.Services.AddSingleton<ISubscriberRepository, CosmosDbSubscriberRepository>();
                logger.LogInformation("Registered CosmosDbSubscriberRepository");
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
    // Check if we have required configuration
    string storageAccount = builder.Configuration["Storage:AccountName"] ?? "";
    string blobEndpoint = builder.Configuration["Storage:BlobEndpoint"] ?? "";

    logger.LogInformation("Storage Account: {StorageAccount}", storageAccount);
    logger.LogInformation("Blob Endpoint: {BlobEndpoint}", blobEndpoint);

    if (string.IsNullOrEmpty(storageAccount) || string.IsNullOrEmpty(blobEndpoint))
    {
        logger.LogWarning("Azure Storage settings incomplete. Using local image storage instead.");
        logger.LogWarning($"StorageAccount: {(string.IsNullOrEmpty(storageAccount) ? "missing" : "present")}");
        logger.LogWarning($"BlobEndpoint: {(string.IsNullOrEmpty(blobEndpoint) ? "missing" : "present")}");
        builder.Services.AddSingleton<IImageService, LocalImageService>();
    }
    else
    {
        logger.LogInformation("Using Azure Blob Storage for images...");
        logger.LogInformation($"Storage Account: {storageAccount}");
        logger.LogInformation($"Blob Endpoint: {blobEndpoint}");
        builder.Services.AddSingleton<IImageService, AzureBlobImageService>();
    }
}
else
{
    logger.LogInformation("Using local image storage...");
    builder.Services.AddSingleton<IImageService, LocalImageService>();
}

builder.Services.AddControllersWithViews();

var app = builder.Build();

// Create deploy timestamp file for tracking deployments
try
{
    File.WriteAllText("deploy-timestamp.txt", DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"));
    logger.LogInformation("Created deployment timestamp file");
}
catch (Exception ex)
{
    logger.LogWarning(ex, "Failed to create deployment timestamp file");
}

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