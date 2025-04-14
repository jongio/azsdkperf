using Azure.Data.Tables;
using Azure.Identity;
using DotEnv.Core;

// Parse command line args - look for --excludeMI argument
var excludeManagedIdentity = false;
for (int i = 0; i < args.Length - 1; i++)
{
    if (args[i] == "--excludeMI")
    {
        excludeManagedIdentity = args[i + 1].Equals("true", StringComparison.OrdinalIgnoreCase) || 
                                args[i + 1].Equals("1", StringComparison.OrdinalIgnoreCase);
        break;
    }
}

new EnvLoader().Load();

var subscriptionId = Environment.GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID");
var storageAccountName = Environment.GetEnvironmentVariable("STORAGE_ACCOUNT_NAME");

if (string.IsNullOrEmpty(subscriptionId) || string.IsNullOrEmpty(storageAccountName))
{
    throw new Exception("Please set AZURE_SUBSCRIPTION_ID and STORAGE_ACCOUNT_NAME in .env file");
}

Console.WriteLine($"Excluding Managed Identity authentication: {excludeManagedIdentity}");

var options = new DefaultAzureCredentialOptions
{
    ExcludeManagedIdentityCredential = excludeManagedIdentity
};
var credential = new DefaultAzureCredential(options);
var serviceUri = new Uri($"https://{storageAccountName}.table.core.windows.net");
var tableServiceClient = new TableServiceClient(serviceUri, credential);

Console.WriteLine($"Listing tables in {storageAccountName}:");
Console.WriteLine("----------------------------------------");

await foreach (var table in tableServiceClient.QueryAsync())
{
    Console.WriteLine(table.Name);
}
