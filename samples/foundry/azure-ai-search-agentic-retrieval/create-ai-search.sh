#!/bin/bash

# Azure AI Search Resource Creation Script
# This script creates an Azure AI Search resource for the agentic retrieval sample
# Resource Group: diberry-ai
# Uses the currently active Azure subscription

set -e  # Exit on any error

# Configuration variables
RESOURCE_GROUP_NAME=""
SEARCH_SERVICE_NAME="search-agentic-retrieval-$(date +%Y%m%d%H%M%S)"  # Unique name with timestamp
LOCATION="eastus"  # Change as needed
SKU="basic"  # Options: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2
REPLICA_COUNT=1
PARTITION_COUNT=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Azure AI Search Resource Creation Script${NC}"
echo -e "${BLUE}============================================${NC}"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠️ Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Display current subscription
CURRENT_SUBSCRIPTION=$(az account show --query "name" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
echo -e "${BLUE}📋 Current Subscription: ${NC}${CURRENT_SUBSCRIPTION} (${SUBSCRIPTION_ID})"

# Check if resource group exists
echo -e "${BLUE}🔍 Checking if resource group '${RESOURCE_GROUP_NAME}' exists...${NC}"
if ! az group show --name $RESOURCE_GROUP_NAME &> /dev/null; then
    echo -e "${YELLOW}⚠️ Resource group '${RESOURCE_GROUP_NAME}' does not exist.${NC}"
    read -p "Do you want to create it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}📦 Creating resource group '${RESOURCE_GROUP_NAME}' in ${LOCATION}...${NC}"
        az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
        echo -e "${GREEN}✅ Resource group created successfully.${NC}"
    else
        echo -e "${RED}❌ Cannot proceed without resource group. Exiting.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Resource group '${RESOURCE_GROUP_NAME}' exists.${NC}"
fi

# Check quota and availability for Azure Search in the region
echo -e "${BLUE}🔍 Checking Azure Search availability in ${LOCATION}...${NC}"

# Validate the deployment first (dry-run)
echo -e "${BLUE}🧪 Validating Azure Search service configuration...${NC}"
VALIDATION_RESULT=$(az search service create \
    --name $SEARCH_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --sku $SKU \
    --replica-count $REPLICA_COUNT \
    --partition-count $PARTITION_COUNT \
    --validate-only \
    --output json 2>&1) || true

if [[ $VALIDATION_RESULT == *"error"* ]]; then
    echo -e "${RED}❌ Validation failed:${NC}"
    echo "$VALIDATION_RESULT"
    exit 1
fi

echo -e "${GREEN}✅ Configuration validation passed.${NC}"

# Display configuration summary
echo -e "${BLUE}📋 Configuration Summary:${NC}"
echo -e "   Service Name: ${SEARCH_SERVICE_NAME}"
echo -e "   Resource Group: ${RESOURCE_GROUP_NAME}"
echo -e "   Location: ${LOCATION}"
echo -e "   SKU: ${SKU}"
echo -e "   Replica Count: ${REPLICA_COUNT}"
echo -e "   Partition Count: ${PARTITION_COUNT}"
echo

# Confirm before creation
read -p "Do you want to proceed with creating the Azure AI Search service? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️ Operation cancelled by user.${NC}"
    exit 0
fi

# Create the Azure AI Search service
echo -e "${BLUE}🚧 Creating Azure AI Search service '${SEARCH_SERVICE_NAME}'...${NC}"
echo -e "${YELLOW}⏳ This may take a few minutes...${NC}"

az search service create \
    --name $SEARCH_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --sku $SKU \
    --replica-count $REPLICA_COUNT \
    --partition-count $PARTITION_COUNT \
    --output table

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Azure AI Search service created successfully!${NC}"
    
    # Get the search service details
    echo -e "${BLUE}📊 Retrieving service details...${NC}"
    SEARCH_ENDPOINT=$(az search service show --name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --query "hostName" -o tsv)
    
    echo -e "${GREEN}🎉 Service Details:${NC}"
    echo -e "   Search Service Name: ${SEARCH_SERVICE_NAME}"
    echo -e "   Search Endpoint: https://${SEARCH_ENDPOINT}"
    echo -e "   Resource Group: ${RESOURCE_GROUP_NAME}"
    echo -e "   Location: ${LOCATION}"
    
    # Get admin keys (for development purposes)
    echo -e "${BLUE}🔑 Retrieving admin keys...${NC}"
    ADMIN_KEY=$(az search admin-key show --service-name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --query "primaryKey" -o tsv)
    
    echo -e "${YELLOW}⚠️ Admin Key (store securely):${NC} ${ADMIN_KEY}"
    
    # Create environment variables for the sample
    echo -e "${BLUE}📝 Environment Variables for your sample:${NC}"
    echo "AZURE_SEARCH_ENDPOINT=https://${SEARCH_ENDPOINT}"
    echo "AZURE_SEARCH_ADMIN_KEY=${ADMIN_KEY}"
    
    # Create .env file template
    ENV_FILE="sample-search.env"
    echo -e "${BLUE}📄 Creating ${ENV_FILE} file...${NC}"
    cat > $ENV_FILE << EOF
# Azure AI Search Configuration
AZURE_SEARCH_ENDPOINT=https://${SEARCH_ENDPOINT}
AZURE_SEARCH_ADMIN_KEY=${ADMIN_KEY}

# Add your other environment variables here
# AZURE_OPENAI_ENDPOINT=https://your-ai-foundry-resource.openai.azure.com/
# AZURE_OPENAI_GPT_DEPLOYMENT=gpt-4
# AZURE_OPENAI_EMBEDDING_DEPLOYMENT=text-embedding-3-large
# OPENAI_API_VERSION=2024-10-21
EOF
    
    echo -e "${GREEN}✅ Environment file '${ENV_FILE}' created.${NC}"
    echo -e "${YELLOW}⚠️ Remember to add your OpenAI configuration to the .env file!${NC}"
    
    # Security recommendations
    echo -e "${BLUE}🔒 Security Recommendations:${NC}"
    echo -e "   1. Store the admin key securely (e.g., Azure Key Vault)"
    echo -e "   2. Consider using Azure RBAC instead of admin keys for production"
    echo -e "   3. Enable firewall rules to restrict access"
    echo -e "   4. Monitor usage and set up alerts"
    
else
    echo -e "${RED}❌ Failed to create Azure AI Search service.${NC}"
    exit 1
fi

echo -e "${BLUE}🎉 Script completed successfully!${NC}"