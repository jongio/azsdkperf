# Azure SDK Performance Comparison

Compare performance between different Azure SDK implementations and CLI for common storage operations.

## Prerequisites

- .NET 9.0 SDK
- Python 3.8+
- Node.js 18+
- Java 17+
- Maven 3.6+
- Azure CLI
- osslsigncode (for Linux code signing verification)

On Linux systems, install osslsigncode:
```bash
sudo apt-get update && sudo apt-get install -y osslsigncode
```

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

2. Start PowerShell:
   - Windows: Open PowerShell
   - Linux/macOS:
     ```bash
     pwsh
     ```

3. .NET Setup
```bash
cd net
dotnet restore
```

4. Python Setup
```bash
cd python
python -m venv .venv

# Windows
.venv\Scripts\Activate.ps1

# Linux/macOS
./.venv/bin/Activate.ps1

pip install -r requirements.txt
```

5. Node.js Setup
```bash
cd js
npm install
```

## Java

Run the Java project using Maven:
```bash
mvn -f java/pom.xml clean package exec:java -Dexec.mainClass="com.azsdkperf.App"
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

## Code Signing

Before running performance comparisons with signed assemblies:

1. Create a development certificate:
   ```powershell
   .\New-CodeSigningCert.ps1 -CertName "azuresdk"
   ```

2. Install the certificate when prompted using the default password: `Dev123!@#`

3. Run comparisons with signing enabled:
   ```powershell
   .\Compare-CommandTimes.ps1 -CertificateSubject "CN=azuresdk" -IncludeSigning
   ```

Note: This uses a self-signed certificate for development purposes only.
