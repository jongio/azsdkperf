require('dotenv').config({ path: '../.env' });
const { TableServiceClient } = require("@azure/data-tables");
const { DefaultAzureCredential } = require("@azure/identity");

const subscriptionId = process.env.AZURE_SUBSCRIPTION_ID;
const storageAccountName = process.env.STORAGE_ACCOUNT_NAME;

if (!subscriptionId || !storageAccountName) {
    throw new Error("Please set AZURE_SUBSCRIPTION_ID and STORAGE_ACCOUNT_NAME in .env file");
}

async function listTables() {
    const credential = new DefaultAzureCredential();
    const serviceUri = `https://${storageAccountName}.table.core.windows.net`;
    const tableService = new TableServiceClient(serviceUri, credential);

    console.log(`Listing tables in ${storageAccountName}:`);
    console.log("----------------------------------------");

    for await (const table of tableService.listTables()) {
        console.log(table.name);
    }
}

listTables().catch(console.error);
