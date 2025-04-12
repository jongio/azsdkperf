# Azure SDK Performance Comparison

This project compares the performance between Azure SDK for .NET and Azure CLI when listing tables in a Storage Account.

## Prerequisites

1. Install Azure CLI
```powershell
winget install Microsoft.AzureCLI
# or
choco install azure-cli
```

2. Install .NET 9.0 SDK
3. Azure Subscription with Storage Account access

## Setup

1. Login to Azure CLI:
```powershell
az login
```

2. Create a Storage Account and Table:
```powershell
# Set variables
$resourceGroup = "your-rg-name"
$location = "eastus"
$storageAccount = "youraccountname"
$tableName = "testtable"

# Create Resource Group if needed
az group create --name $resourceGroup --location $location

# Create Storage Account
az storage account create `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --location $location `
    --sku Standard_LRS

# Create Table
az storage table create `
    --name $tableName `
    --account-name $storageAccount `
    --auth-mode login
```

3. Configure environment:
```powershell
# Copy sample env file
Copy-Item .env.sample .env

# Edit .env file with your values:
# AZURE_SUBSCRIPTION_ID=your-subscription-id
# STORAGE_ACCOUNT_NAME=your-storage-account-name
```

## Run Performance Comparison

Execute the comparison script:
```powershell
.\Compare-CommandTimes.ps1
```

This will output the execution times for both the .NET SDK and Azure CLI approaches.
