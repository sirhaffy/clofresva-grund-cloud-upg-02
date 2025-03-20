using MVC_TestApp.Models;

namespace MVC_TestApp.Repositories;

public class InMemorySubscriberRepository : ISubscriberRepository
{
    private readonly List<Subscriber> _subscribers = new();

    public Task<IEnumerable<Subscriber>> GetSubscribers()
    {
        return Task.FromResult(_subscribers.AsEnumerable());
    }

    public Task<IEnumerable<Subscriber>> GetSubscribersAsync()
    {
        return Task.FromResult(_subscribers.AsEnumerable());
    }

    public Task<Subscriber?> GetSubscriberAsync(string email)
    {
        return Task.FromResult(_subscribers.FirstOrDefault(s => s.Email == email));
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
        // existingSubscriber.FirstName = subscriber.FirstName;
        // existingSubscriber.LastName = subscriber.LastName;
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