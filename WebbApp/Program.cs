using DotNetEnv;
using MongoDB.Driver;
using FluentValidation;
using FluentValidation.AspNetCore;
using MVC_TestApp.Controllers;
using MVC_TestApp.Models;
using MVC_TestApp.Repositories;
using MVC_TestApp.Services;
using MVC_TestApp.Storage;

// Ladda miljövariabler från .env
Env.Load("../.env");

var builder = WebApplication.CreateBuilder(args);

// Lägg till miljövariabler till konfigurationen
builder.Configuration.AddEnvironmentVariables();

// Konfigurera loggning
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
var logger = loggerFactory.CreateLogger("Program");

// Registrera gemensamma tjänster
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<INewsletterService, NewsletterService>();
builder.Services.AddScoped<IValidator<Subscriber>, UserValidator>();
builder.Services.AddFluentValidationAutoValidation();

// Läs in vilket repository som ska användas (standard = inmemory om inget annat anges)
string repoType = builder.Configuration.GetValue<string>("SUBSCRIBER_REPOSITORY", "inmemory").ToLowerInvariant();
logger.LogInformation($"Using subscriber repository type: {repoType}");

// Around line 35-40 in Program.cs
if (repoType == "mongo" || repoType == "cosmos")
{
    // Get connection string from configuration
    string connectionString = builder.Configuration.GetSection("MongoDB:ConnectionString").Value;

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
    logger.LogInformation("Registrerar InMemorySubscriberRepository.");
}
else
{
    logger.LogWarning($"Okänt SUBSCRIBER_REPOSITORY-värde '{repoType}'. Använder standard: InMemory.");
    builder.Services.AddSingleton<ISubscriberRepository, InMemorySubscriberRepository>();
}

// Läs in flaggan för bildlagring via FEATUREFLAGS__USEAZURESTORAGE.
bool useAzureStorage = builder.Configuration.GetValue<bool>("FEATUREFLAGS:USEAZURESTORAGE", false);
logger.LogInformation($"FEATUREFLAGS: USEAZURESTORAGE = {useAzureStorage}");

// Välj bildlagringstjänst baserat på flaggan.
// Om flaggan är true: använd AzureBlobImageService, annars LocalImageService.
if (useAzureStorage)
{
    logger.LogInformation("Använder Azure Blob Storage för bilder...");
    builder.Services.AddSingleton<IImageService, AzureBlobImageService>();
}
else
{
    logger.LogInformation("Använder lokal bildlagring...");
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
