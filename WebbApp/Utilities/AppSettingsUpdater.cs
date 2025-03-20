using System;
using System.IO;
using System.Text.Json;

namespace MVC_TestApp.Utilities
{
    public static class AppSettingsUpdater
    {
        public static void UpdateAppSettingsFromEnv(string jsonFilePath)
        {
            // Hämta miljövariabler från .env
            var mongoDbConfig = new
            {
                ConnectionString = Environment.GetEnvironmentVariable("MONGODB__CONNECTIONSTRING"),
                DatabaseName = "cloudsoft",
                SubscribersCollectionName = "subscribers"
            };

            var azureBlobConfig = new
            {
                ContainerUrl = $"https://{Environment.GetEnvironmentVariable("AZUREBLOB__ACCOUNTNAME")}.blob.core.windows.net/{Environment.GetEnvironmentVariable("AZUREBLOB__CONTAINER")}"
            };

            // Skapa en uppdaterad konfiguration baserad på miljövariabler
            var updatedConfig = new
            {
                Logging = new
                {
                    LogLevel = new
                    {
                        Default = "Information",
                        Microsoft_AspNetCore = "Warning"
                    }
                },
                AllowedHosts = "*",
                MongoDb = mongoDbConfig,
                AzureBlob = azureBlobConfig
            };

            // Konvertera objektet till JSON med indentering
            var jsonOptions = new JsonSerializerOptions { WriteIndented = true };
            string updatedJson = JsonSerializer.Serialize(updatedConfig, jsonOptions);

            // Skriv till JSON-filen
            File.WriteAllText(jsonFilePath, updatedJson);
            Console.WriteLine($"Konfigurationen har skrivits till: {jsonFilePath}");
        }
    }
}