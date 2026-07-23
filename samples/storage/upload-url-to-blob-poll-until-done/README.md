---
ai-usage: ai-generated
---

# Copy URLs to blobs and wait for completion

This sample starts Azure Blob Storage copy operations from public URLs and waits for each long-running operation to finish with `pollUntilDone()` before it continues.

## Prerequisites

- Node.js 20 or later.
- An Azure Storage account.
- Azure CLI signed in with `az login`, or another identity supported by `DefaultAzureCredential`.
- The **Storage Blob Data Contributor** role assigned to your identity for the storage account.

## Setup

1. Install dependencies.

   ```bash
   npm install
   ```

1. Set environment variables.

   ```bash
   export AZURE_STORAGE_ACCOUNT_NAME="<storage-account-name>"
   export AZURE_STORAGE_CONTAINER_NAME="<optional-container-name>"
   ```

   `AZURE_STORAGE_CONTAINER_NAME` is optional. If you don't set it, the sample creates a container named `url-copy-<timestamp>`. On Windows PowerShell, use `$env:AZURE_STORAGE_ACCOUNT_NAME` and `$env:AZURE_STORAGE_CONTAINER_NAME` instead.

## Run the sample

1. Build the TypeScript sample.

   ```bash
   npm run build
   ```

1. Run the sample.

   ```bash
   npm start
   ```

## Expected output

The output shows each copied blob after its copy operation reaches a terminal state.

```output
Copying 5 file(s) into container url-copy-1784567890123.
Copied README.md. Copy status: success.
Copied gulpfile.ts. Copy status: success.
Copied rush.json. Copy status: success.
Copied package.json. Copy status: success.
Copied tsdoc.json. Copy status: success.
All copy operations completed.
```
