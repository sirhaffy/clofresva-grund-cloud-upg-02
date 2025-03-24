using MVC_TestApp.Models;

namespace MVC_TestApp.Repositories;

public class InMemorySubscriberRepository : ISubscriberRepository
{
    private readonly List<Subscriber> _subscribers = new();

    public Task<IEnumerable<Subscriber>> GetSubscribersAsync()
    {
        return Task.FromResult(_subscribers.AsEnumerable());
    }

    public Task<Subscriber> GetSubscriberByIdAsync(string id)
    {
        var subscriber = _subscribers.FirstOrDefault(s => s.Id == id);
        return Task.FromResult(subscriber);
    }

    public Task<Subscriber> GetSubscriberByEmailAsync(string email)
    {
        var subscriber = _subscribers.FirstOrDefault(s => s.Email == email);
        return Task.FromResult(subscriber);
    }

    public Task<bool> AddSubscriberAsync(Subscriber subscriber)
    {
        if (_subscribers.Any(s => s.Email == subscriber.Email))
        {
            return Task.FromResult(false);
        }

        _subscribers.Add(subscriber);
        return Task.FromResult(true);
    }

    // Update the subscriber
    public Task<bool> UpdateSubscriberAsync(Subscriber subscriber)
    {
        var existingSubscriber = _subscribers.FirstOrDefault(s => s.Email == subscriber.Email);
        if (existingSubscriber == null)
        {
            return Task.FromResult(false);
        }

        existingSubscriber.Name = subscriber.Name;
        return Task.FromResult(true);
    }

    public Task<bool> DeleteSubscriberAsync(string email)
    {
        var subscriber = _subscribers.FirstOrDefault(s => s.Email == email);
        if (subscriber == null)
        {
            return Task.FromResult(false);
        }

        _subscribers.Remove(subscriber);
        return Task.FromResult(true);
    }

    public Task<bool> ExistsSubscriberAsync(string email)
    {
        return Task.FromResult(_subscribers.Any(s => s.Email == email));
    }
}