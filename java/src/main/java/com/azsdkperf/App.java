package com.azsdkperf;

import com.azure.identity.DefaultAzureCredential;
import com.azure.data.tables.TableServiceClient;
import com.azure.data.tables.TableServiceClientBuilder;
import io.github.cdimascio.dotenv.Dotenv;

public class App {
    public static void main(String[] args) {
        Dotenv dotenv = Dotenv.load();
        
        String subscriptionId = dotenv.get("AZURE_SUBSCRIPTION_ID");
        String storageAccountName = dotenv.get("STORAGE_ACCOUNT_NAME");

        if (subscriptionId == null || storageAccountName == null) {
            throw new RuntimeException("Please set AZURE_SUBSCRIPTION_ID and STORAGE_ACCOUNT_NAME in .env file");
        }

        String serviceUri = String.format("https://%s.table.core.windows.net", storageAccountName);
        TableServiceClient tableServiceClient = new TableServiceClientBuilder()
            .endpoint(serviceUri)
            .credential(new DefaultAzureCredential())
            .buildClient();

        System.out.printf("Listing tables in %s:%n", storageAccountName);
        System.out.println("----------------------------------------");

        tableServiceClient.listTables().forEach(table -> System.out.println(table.getName()));
    }
}
