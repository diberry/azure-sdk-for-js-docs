import { DefaultAzureCredential } from "@azure/identity";
import { BlobServiceClient } from "@azure/storage-blob";

const accountName = process.env.AZURE_STORAGE_ACCOUNT_NAME;
const containerName = process.env.AZURE_STORAGE_CONTAINER_NAME;
const pageSize = 2;

function getRequiredEnvironmentVariable(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Set the ${name} environment variable before running this sample.`);
  }

  return value;
}

async function main(): Promise<void> {
  const storageAccountName = accountName ?? getRequiredEnvironmentVariable("AZURE_STORAGE_ACCOUNT_NAME");
  const storageContainerName = containerName ?? getRequiredEnvironmentVariable("AZURE_STORAGE_CONTAINER_NAME");
  const credential = new DefaultAzureCredential();
  const blobServiceClient = new BlobServiceClient(
    `https://${storageAccountName}.blob.core.windows.net`,
    credential,
  );
  const containerClient = blobServiceClient.getContainerClient(storageContainerName);

  console.log(`Listing blobs in ${storageContainerName} with a page size of ${pageSize}.`);

  let pageNumber = 1;
  let blobNumber = 1;

  for await (const page of containerClient.listBlobsFlat().byPage({ maxPageSize: pageSize })) {
    console.log(`Page ${pageNumber++}`);

    if (page.segment.blobItems.length === 0) {
      console.log("  No blobs found on this page.");
      continue;
    }

    for (const blob of page.segment.blobItems) {
      console.log(`  ${blobNumber++}. ${blob.name}`);
    }
  }

  console.log(`Found ${blobNumber - 1} blob(s).`);
}

main().catch((error: unknown) => {
  console.error("Failed to list blobs by page.");
  console.error(error instanceof Error ? error.message : error);
  console.error(
    "Confirm that the storage account and container exist and that your identity has the Storage Blob Data Reader role.",
  );
  process.exitCode = 1;
});
