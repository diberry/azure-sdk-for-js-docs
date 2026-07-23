import { DefaultAzureCredential } from "@azure/identity";
import { BlobServiceClient } from "@azure/storage-blob";

interface FileToCopy {
  sourceUrl: string;
  blobName: string;
}

const accountName = process.env.AZURE_STORAGE_ACCOUNT_NAME;
const containerName = process.env.AZURE_STORAGE_CONTAINER_NAME ?? `url-copy-${Date.now()}`;

const files: FileToCopy[] = [
  {
    sourceUrl: "https://raw.githubusercontent.com/Azure/azure-sdk-for-js/main/README.md",
    blobName: "README.md",
  },
  {
    sourceUrl: "https://raw.githubusercontent.com/Azure/azure-sdk-for-js/main/gulpfile.ts",
    blobName: "gulpfile.ts",
  },
  {
    sourceUrl: "https://raw.githubusercontent.com/Azure/azure-sdk-for-js/main/rush.json",
    blobName: "rush.json",
  },
  {
    sourceUrl: "https://raw.githubusercontent.com/Azure/azure-sdk-for-js/main/package.json",
    blobName: "package.json",
  },
  {
    sourceUrl: "https://raw.githubusercontent.com/Azure/azure-sdk-for-js/main/tsdoc.json",
    blobName: "tsdoc.json",
  },
];

function getRequiredEnvironmentVariable(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Set the ${name} environment variable before running this sample.`);
  }

  return value;
}

async function main(): Promise<void> {
  const storageAccountName = accountName ?? getRequiredEnvironmentVariable("AZURE_STORAGE_ACCOUNT_NAME");
  const credential = new DefaultAzureCredential();
  const blobServiceClient = new BlobServiceClient(
    `https://${storageAccountName}.blob.core.windows.net`,
    credential,
  );
  const containerClient = blobServiceClient.getContainerClient(containerName);

  await containerClient.createIfNotExists();
  console.log(`Copying ${files.length} file(s) into container ${containerName}.`);

  const failures: string[] = [];

  for (const file of files) {
    try {
      const poller = await containerClient.getBlobClient(file.blobName).beginCopyFromURL(file.sourceUrl);
      const result = await poller.pollUntilDone();
      console.log(`Copied ${file.blobName}. Copy status: ${result.copyStatus}.`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      failures.push(`${file.blobName}: ${message}`);
      console.error(`Failed to copy ${file.blobName}: ${message}`);
    }
  }

  if (failures.length > 0) {
    throw new Error(`Some files failed to copy: ${failures.join("; ")}`);
  }

  console.log("All copy operations completed.");
}

main().catch((error: unknown) => {
  console.error("Failed to copy files from URLs to blobs.");
  console.error(error instanceof Error ? error.message : error);
  console.error(
    "Confirm that the storage account exists, source URLs are reachable, and your identity has the Storage Blob Data Contributor role.",
  );
  process.exitCode = 1;
});
