using MVC_TestApp.Models;

namespace MVC_TestApp.Repositories;

public interface ISubscriberRepository
{
    Task<IEnumerable<Subscriber>> GetSubscribersAsync();
    Task<Subscriber> GetSubscriberByIdAsync(string id);
    Task<Subscriber> GetSubscriberByEmailAsync(string email);
    Task<bool> AddSubscriberAsync(Subscriber subscriber);
    Task<bool> UpdateSubscriberAsync(Subscriber subscriber);
    Task<bool> DeleteSubscriberAsync(string email);
    Task<bool> ExistsSubscriberAsync(string email);
}