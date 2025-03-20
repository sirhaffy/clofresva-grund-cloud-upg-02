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

// Registrera repository enligt vald typ
if (repoType == "mongo" || repoType == "cosmos")
{
    // Beroende på implementation kan du välja olika anslutningssträngar och databasnamn.
    string connectionStringKey = repoType == "mongo" ? "MONGODB:CONNECTIONSTRING" : "COSMOSDB:CONNECTIONSTRING";
    string databaseNameKey = repoType == "mongo" ? "MONGODB:DATABASE" : "COSMOSDB:DATABASE";

    var connectionString = builder.Configuration.GetConnectionString("MongoDB");
    if (!string.IsNullOrEmpty(connectionString))
    {
        builder.Services.AddSingleton<IMongoClient>(new MongoClient(connectionString));
        builder.Services.AddScoped(provider =>
            provider.GetRequiredService<IMongoClient>().GetDatabase("myDatabase"));
    }

    // Registrera Mongo-klient och databas (gemensamt för Mongo och Cosmos)
    builder.Services.AddSingleton<IMongoClient>(new MongoClient(connectionString));
    builder.Services.AddSingleton<IMongoDatabase>(sp =>
    {
        var client = sp.GetRequiredService<IMongoClient>();
        string dbName = builder.Configuration[databaseNameKey] ?? (repoType == "mongo" ? "default_mongo_db" : "default_cosmos_db");
        return client.GetDatabase(dbName);
    });

    if (repoType == "mongo")
    {
        builder.Services.AddSingleton<ISubscriberRepository, MongoDbSubscriberRepository>();
        logger.LogInformation("Registrerar MongoDbSubscriberRepository.");
    }
    else // repoType == "cosmos"
    {
        builder.Services.AddSingleton<ISubscriberRepository, CosmosDbSubscriberRepository>();
        logger.LogInformation("Registrerar CosmosDbSubscriberRepository.");
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
