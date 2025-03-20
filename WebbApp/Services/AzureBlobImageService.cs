using MVC_TestApp.Storage;

namespace MVC_TestApp.Services;

public class AzureBlobImageService : IImageService
{
    private readonly IConfiguration _configuration;
    
    public AzureBlobImageService(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    
    public string GetImageUrl(string imageName)
    {
        // Hämta specifika inställningar direkt från miljövariablerna
        var accountName = _configuration["AZUREBLOB:ACCOUNTNAME"];
        var containerName = _configuration["AZUREBLOB:CONTAINER"];
        if (string.IsNullOrWhiteSpace(accountName) || string.IsNullOrWhiteSpace(containerName))
        {
            throw new InvalidOperationException("Azure Blob Storage-konfiguration saknas.");
        }
        
        return $"https://{accountName}.blob.core.windows.net/{containerName}/{imageName}";
    }
}