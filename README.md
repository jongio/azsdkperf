# Azure SDK Performance Comparison

Compare performance between different Azure SDK implementations and CLI for common storage operations.

## Prerequisites

- .NET 9.0 SDK
- Python 3.8+
- Node.js 18+
- Azure CLI

## Azure Setup

1. Install the Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli
2. Login to Azure:
```bash
az login
```

3. Create a storage account and table:
```bash
# Create resource group
az group create --name mystorage-rg --location eastus

# Create storage account
az storage account create --name mystorageacct --resource-group mystorage-rg --location eastus --sku Standard_LRS

# Create table
az storage table create --name mytable --account-name mystorageacct
```

## Project Setup

1. Create a `.env` file in the root directory with:
```
AZURE_SUBSCRIPTION_ID=your_subscription_id
STORAGE_ACCOUNT_NAME=mystorageacct
```

2. .NET Setup
```bash
cd net
dotnet restore
```

3. Python Setup
```bash
cd python
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

4. Node.js Setup
```bash
cd js
npm install
```

## Running Performance Tests

```powershell
.\Compare-CommandTimes.ps1
```

This will execute the same storage operation using:
- .NET SDK
- Python SDK
- Node.js SDK
- Azure CLI

and compare their execution times.
