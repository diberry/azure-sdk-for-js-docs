---
ai-usage: ai-generated
---

# Page through blobs

This sample lists blobs in an Azure Storage container by using `PagedAsyncIterableIterator` and `byPage`. The page size is intentionally set to `2` so you can see multiple pages when the container has several blobs.

## Prerequisites

- Node.js 20 or later.
- An Azure Storage account with a blob container that contains blobs to list.
- Azure CLI signed in with `az login`, or another identity supported by `DefaultAzureCredential`.
- The **Storage Blob Data Reader** role assigned to your identity for the storage account or container.

## Setup

1. Install dependencies.

   ```bash
   npm install
   ```

1. Set environment variables.

   ```bash
   export AZURE_STORAGE_ACCOUNT_NAME="<storage-account-name>"
   export AZURE_STORAGE_CONTAINER_NAME="<container-name>"
   ```

   On Windows PowerShell, use `$env:AZURE_STORAGE_ACCOUNT_NAME` and `$env:AZURE_STORAGE_CONTAINER_NAME` instead.

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

The output shows each page and the blobs in that page.

```output
Listing blobs in samples with a page size of 2.
Page 1
  1. first.txt
  2. second.txt
Page 2
  3. third.txt
Found 3 blob(s).
```
