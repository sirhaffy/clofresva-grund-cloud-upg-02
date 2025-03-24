using MVC_TestApp.Models;
using MongoDB.Driver;

namespace MVC_TestApp.Repositories;

public class MongoDbSubscriberRepository : ISubscriberRepository
{
    private readonly IMongoCollection<Subscriber> _subscribers;

    public MongoDbSubscriberRepository(IMongoDatabase database)
    {
        _subscribers = database.GetCollection<Subscriber>("Subscribers");
    }
    
    // Get all subscribers
    public async Task<IEnumerable<Subscriber>> GetSubscribersAsync()
    {
        return await _subscribers.Find(s => true).ToListAsync();
    }

    public async Task<Subscriber> GetSubscriberByIdAsync(string id)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Id, id);
        return await _subscribers.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<Subscriber> GetSubscriberByEmailAsync(string email)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
        return await _subscribers.Find(filter).FirstOrDefaultAsync();
    }

    // Add a subscriber
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
    
    // Update a subscriber
    public async Task<bool> UpdateSubscriberAsync(Subscriber subscriber)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, subscriber.Email);
        var result = await _subscribers.ReplaceOneAsync(filter, subscriber);
        return result.ModifiedCount > 0;
    }

    // Delete a subscriber
    public async Task<bool> DeleteSubscriberAsync(string email)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
        var result = await _subscribers.DeleteOneAsync(filter);
        return result.DeletedCount > 0;
    }

    // Check if a subscriber exists
    public async Task<bool> ExistsSubscriberAsync(string email)
    {
        var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
        var result = await _subscribers.Find(filter).FirstOrDefaultAsync();
        return result != null;
    }
}