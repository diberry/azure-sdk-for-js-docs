// <CREDENTIAL_CHAIN_DEBUG
import { setLogLevel, AzureLogger } from "@azure/logger";
import { BlobServiceClient } from "@azure/storage-blob";
import { 
    ChainedTokenCredential, 
    AzureDeveloperCliCredential,
    AzureCliCredential 
} from "@azure/identity";

// Constant for the Azure identity log prefix
const AZURE_IDENTITY_LOG_PREFIX = "azure:identity";

// override logging to output to console.log (default location is stderr)
// only log messages that start with the Azure identity log prefix
setLogLevel("verbose");
AzureLogger.log = (...args) => {
  const message = args[0];
  if (typeof message === 'string' && message.startsWith(AZURE_IDENTITY_LOG_PREFIX)) {
    console.log(...args);
  }
};

// Get storage account name from environment variable
const storageAccountName = process.env.AZURE_STORAGE_ACCOUNT_NAME;

if (!storageAccountName) {
    throw new Error("AZURE_STORAGE_ACCOUNT_NAME environment variable is required");
}

const credential = new ChainedTokenCredential(
    new AzureDeveloperCliCredential(),
    new AzureCliCredential()
);

const blobServiceClient = new BlobServiceClient(
    `https://${storageAccountName}.blob.core.windows.net`,
    credential
);
// </CREDENTIAL_CHAIN_DEBUG

// Function to list containers
async function listContainers() {
    try {
        console.log("Listing containers...");
        
        const containerIterator = blobServiceClient.listContainers();
        
        for await (const container of containerIterator) {
            console.log(`Container: ${container.name}`);
            console.log(`  Last Modified: ${container.properties.lastModified}`);
            console.log(`  ETag: ${container.properties.etag}`);
            console.log(`  Public Access: ${container.properties.publicAccess || 'None'}`);
            console.log('---');
        }
        
        console.log("Container listing completed successfully!");
    } catch (error) {
        console.error("Error listing containers:", error);
        if (error instanceof Error) {
            console.error("Error message:", error.message);
        }
    }
}

// Call the function to list containers
listContainers().catch(console.error);
