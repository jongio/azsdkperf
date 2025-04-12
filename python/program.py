from azure.data.tables import TableServiceClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
import os

load_dotenv()

subscription_id = os.getenv('AZURE_SUBSCRIPTION_ID')
storage_account_name = os.getenv('STORAGE_ACCOUNT_NAME')

if not subscription_id or not storage_account_name:
    raise Exception("Please set AZURE_SUBSCRIPTION_ID and STORAGE_ACCOUNT_NAME in .env file")

credential = DefaultAzureCredential()
service_uri = f"https://{storage_account_name}.table.core.windows.net"
table_service_client = TableServiceClient(endpoint=service_uri, credential=credential)

print(f"Listing tables in {storage_account_name}:")
print("----------------------------------------")

tables = table_service_client.list_tables()
for table in tables:
    print(table.name)
