using MVC_TestApp.Models;

namespace MVC_TestApp.Services;

public interface INewsletterService
{
    Task<OperationResult> SignUpAsync(Subscriber subscriber);
    Task<OperationResult> UnsubscribeAsync(string email);
    Task<IEnumerable<Subscriber>> GetSubscribersAsync();
}