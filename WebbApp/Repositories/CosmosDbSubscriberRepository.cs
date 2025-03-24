using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using MongoDB.Driver;
using MVC_TestApp.Models;

namespace MVC_TestApp.Repositories
{
    public class CosmosDbSubscriberRepository : ISubscriberRepository
    {
        private readonly IMongoCollection<Subscriber> _subscribers;
        private readonly ILogger<CosmosDbSubscriberRepository> _logger;
        private bool _isConnectionValid = false;

        public CosmosDbSubscriberRepository(IMongoDatabase database, ILogger<CosmosDbSubscriberRepository> logger)
        {
            _logger = logger;

            try
            {
                _logger.LogInformation("Initializing CosmosDbSubscriberRepository");
                string collectionName = "subscribers";
                _subscribers = database.GetCollection<Subscriber>(collectionName);

                // Test the connection with a simple operation
                _subscribers.CountDocuments(FilterDefinition<Subscriber>.Empty);
                _isConnectionValid = true;
                _logger.LogInformation("Successfully connected to Cosmos DB collection: {Collection}", collectionName);
            }
            catch (Exception ex)
            {
                _isConnectionValid = false;
                _logger.LogError(ex, "Failed to connect to Cosmos DB collection");
                throw; // Rethrow to let DI container handle it
            }
        }

        public async Task<IEnumerable<Subscriber>> GetSubscribersAsync()
        {
            _logger.LogInformation("Getting all subscribers from CosmosDB");
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Returning empty list.");
                return new List<Subscriber>();
            }

            try
            {
                var subscribers = await _subscribers.Find(_ => true).ToListAsync();
                _logger.LogInformation("Retrieved {Count} subscribers from CosmosDB", subscribers.Count);
                return subscribers;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting subscribers from Cosmos DB");
                throw; // Let the exception bubble up for better diagnostics
            }
        }

        public async Task<Subscriber> GetSubscriberByIdAsync(string id)
        {
            _logger.LogInformation("Getting subscriber by ID: {Id}", id);
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Returning null.");
                return null;
            }

            try
            {
                var filter = Builders<Subscriber>.Filter.Eq(s => s.Id, id);
                return await _subscribers.Find(filter).FirstOrDefaultAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting subscriber by ID {Id}", id);
                throw;
            }
        }

        public async Task<Subscriber> GetSubscriberByEmailAsync(string email)
        {
            _logger.LogInformation("Getting subscriber by email: {Email}", email);
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Returning null.");
                return null;
            }

            try
            {
                var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
                return await _subscribers.Find(filter).FirstOrDefaultAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting subscriber by email {Email}", email);
                throw;
            }
        }

        public async Task<bool> AddSubscriberAsync(Subscriber subscriber)
        {
            _logger.LogInformation("Adding new subscriber: {Email}", subscriber.Email);
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Cannot add subscriber.");
                return false;
            }

            try
            {
                await _subscribers.InsertOneAsync(subscriber);
                _logger.LogInformation("Successfully added subscriber: {Email}", subscriber.Email);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error adding subscriber {Email}", subscriber.Email);
                return false;
            }
        }

        public async Task<bool> UpdateSubscriberAsync(Subscriber subscriber)
        {
            _logger.LogInformation("Updating subscriber: {Id}, {Email}", subscriber.Id, subscriber.Email);
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Cannot update subscriber.");
                return false;
            }

            try
            {
                var filter = Builders<Subscriber>.Filter.Eq(s => s.Id, subscriber.Id);
                var result = await _subscribers.ReplaceOneAsync(filter, subscriber);
                _logger.LogInformation("Successfully updated subscriber: {Email}, ModifiedCount: {Count}", 
                    subscriber.Email, result.ModifiedCount);
                
                return result.ModifiedCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating subscriber {Id}, {Email}", subscriber.Id, subscriber.Email);
                return false;
            }
        }

        public async Task<bool> DeleteSubscriberAsync(string email)
        {
            _logger.LogInformation("Deleting subscriber by email: {Email}", email);
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Cannot delete subscriber.");
                return false;
            }

            try
            {
                // Först hitta prenumeranten för att få ID
                var subscriber = await GetSubscriberByEmailAsync(email);
                if (subscriber == null)
                {
                    _logger.LogWarning("Subscriber not found for deletion: {Email}", email);
                    return false;
                }

                // Ta bort med ID som är partitionsnyckel i Cosmos DB
                var filter = Builders<Subscriber>.Filter.Eq(s => s.Id, subscriber.Id);
                var result = await _subscribers.DeleteOneAsync(filter);
                
                _logger.LogInformation("Delete result for subscriber {Email}: DeletedCount={Count}", 
                    email, result.DeletedCount);
                
                return result.DeletedCount > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting subscriber by email {Email}", email);
                return false;
            }
        }

        public async Task<bool> ExistsSubscriberAsync(string email)
        {
            _logger.LogInformation("Checking if subscriber exists: {Email}", email);
            if (!_isConnectionValid)
            {
                _logger.LogWarning("Connection to Cosmos DB is not valid. Cannot check if subscriber exists.");
                return false;
            }

            try
            {
                var filter = Builders<Subscriber>.Filter.Eq(s => s.Email, email);
                var count = await _subscribers.CountDocumentsAsync(filter);
                return count > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking if subscriber exists {Email}", email);
                return false;
            }
        }
    }
}