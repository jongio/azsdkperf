using Azure.Data.Tables;
using Azure.Identity;
using DotEnv.Core;

new EnvLoader().Load();

var subscriptionId = Environment.GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID");
var storageAccountName = Environment.GetEnvironmentVariable("STORAGE_ACCOUNT_NAME");

if (string.IsNullOrEmpty(subscriptionId) || string.IsNullOrEmpty(storageAccountName))
{
    throw new Exception("Please set AZURE_SUBSCRIPTION_ID and STORAGE_ACCOUNT_NAME in .env file");
}

var credential = new DefaultAzureCredential();
var serviceUri = new Uri($"https://{storageAccountName}.table.core.windows.net");
var tableServiceClient = new TableServiceClient(serviceUri, credential);

Console.WriteLine($"Listing tables in {storageAccountName}:");
Console.WriteLine("----------------------------------------");

await foreach (var table in tableServiceClient.QueryAsync())
{
    Console.WriteLine(table.Name);
}
