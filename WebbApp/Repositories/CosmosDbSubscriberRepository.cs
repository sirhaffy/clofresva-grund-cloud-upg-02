using MVC_TestApp.Models;
using MongoDB.Driver;

namespace MVC_TestApp.Repositories;

public class CosmosDbSubscriberRepository : ISubscriberRepository
{
    private readonly IMongoCollection<Subscriber> _subscribers;

    public CosmosDbSubscriberRepository(IMongoDatabase database)
    {
        _subscribers = database.GetCollection<Subscriber>("Subscribers");
    }

    public async Task<IEnumerable<Subscriber>> GetSubscribersAsync() =>
        await _subscribers.Find(s => true).ToListAsync();

    public async Task<Subscriber?> GetSubscriberAsync(string email)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
        return await _subscribers.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<bool> AddSubscriberAsync(Subscriber subscriber)
    {
        try
        {
            await _subscribers.InsertOneAsync(subscriber);
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public async Task<bool> UpdateSubscriberAsync(Subscriber subscriber)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, subscriber.Email);
        var result = await _subscribers.ReplaceOneAsync(filter, subscriber);
        return result.ModifiedCount > 0;
    }

    public async Task<bool> DeleteSubscriberAsync(string email)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
        var result = await _subscribers.DeleteOneAsync(filter);
        return result.DeletedCount > 0;
    }

    public async Task<bool> ExistsSubscriberAsync(string email)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
        var result = await _subscribers.Find(filter).FirstOrDefaultAsync();
        return result != null;
    }
}