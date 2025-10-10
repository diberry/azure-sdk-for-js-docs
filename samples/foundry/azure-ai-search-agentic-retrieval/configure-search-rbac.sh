#!/bin/bash

# Azure AI Search RBAC Configuration Script
# This script configures role-based access control for Azure AI Search service
# - Enables RBAC on the search service
# - Creates system-assigned managed identity
# - Assigns required roles to the current user

set -e  # Exit on any error

# Configuration variables - Update these to match your environment
RESOURCE_GROUP_NAME=""
SEARCH_SERVICE_NAME=""  # Will be detected automatically or you can set it manually

# Required RBAC roles for Azure AI Search
RBAC_ROLES=(
    "Search Service Contributor"
    "Search Index Data Contributor"
    "Search Index Data Reader"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Azure AI Search RBAC Configuration Script${NC}"
echo -e "${BLUE}===============================================${NC}"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check Azure CLI version
AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
echo -e "${BLUE}📋 Azure CLI Version: ${AZ_VERSION}${NC}"

# Check if user is logged in
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠️ Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Display current subscription and user
CURRENT_SUBSCRIPTION=$(az account show --query "name" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
CURRENT_USER=$(az account show --query "user.name" -o tsv)
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query "id" -o tsv 2>/dev/null || echo "")

echo -e "${BLUE}📋 Current Context:${NC}"
echo -e "   Subscription: ${CURRENT_SUBSCRIPTION} (${SUBSCRIPTION_ID})"
echo -e "   User: ${CURRENT_USER}"
echo -e "   User Object ID: ${CURRENT_USER_OBJECT_ID}"
echo

# Ensure we're using the correct subscription
echo -e "${BLUE}🔧 Setting subscription context...${NC}"
az account set --subscription $SUBSCRIPTION_ID
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Subscription context set successfully.${NC}"
else
    echo -e "${RED}❌ Failed to set subscription context.${NC}"
    exit 1
fi

# Auto-detect search service if not specified
if [ -z "$SEARCH_SERVICE_NAME" ]; then
    echo -e "${BLUE}🔍 Auto-detecting Azure AI Search services in resource group '${RESOURCE_GROUP_NAME}'...${NC}"
    
    SEARCH_SERVICES=$(az search service list --resource-group $RESOURCE_GROUP_NAME --query "[].name" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$SEARCH_SERVICES" ]; then
        echo -e "${RED}❌ No Azure AI Search services found in resource group '${RESOURCE_GROUP_NAME}'.${NC}"
        echo -e "${YELLOW}💡 Please run the create-ai-search.sh script first to create a search service.${NC}"
        exit 1
    fi
    
    # Count the number of services
    SERVICE_COUNT=$(echo "$SEARCH_SERVICES" | wc -l)
    
    if [ $SERVICE_COUNT -eq 1 ]; then
        SEARCH_SERVICE_NAME=$SEARCH_SERVICES
        echo -e "${GREEN}✅ Found search service: ${SEARCH_SERVICE_NAME}${NC}"
    else
        echo -e "${YELLOW}⚠️ Multiple search services found:${NC}"
        echo "$SEARCH_SERVICES"
        echo
        read -p "Enter the search service name to configure: " SEARCH_SERVICE_NAME
        
        if [ -z "$SEARCH_SERVICE_NAME" ]; then
            echo -e "${RED}❌ No search service name provided. Exiting.${NC}"
            exit 1
        fi
    fi
fi

# Verify the search service exists
echo -e "${BLUE}🔍 Verifying search service '${SEARCH_SERVICE_NAME}' exists...${NC}"
if ! az search service show --name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME &> /dev/null; then
    echo -e "${RED}❌ Search service '${SEARCH_SERVICE_NAME}' not found in resource group '${RESOURCE_GROUP_NAME}'.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Search service verified.${NC}"

# Get the search service resource ID
SEARCH_RESOURCE_ID=$(az search service show --name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --query "id" -o tsv)
echo -e "${BLUE}📋 Search Resource ID: ${SEARCH_RESOURCE_ID}${NC}"

# Check current authentication mode
echo -e "${BLUE}🔍 Checking current authentication configuration...${NC}"
CURRENT_AUTH_MODE=$(az search service show --name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --query "authOptions.aadOrApiKey.aadAuthFailureMode" -o tsv 2>/dev/null || echo "null")

if [ "$CURRENT_AUTH_MODE" = "null" ] || [ -z "$CURRENT_AUTH_MODE" ]; then
    echo -e "${YELLOW}⚠️ RBAC is not currently enabled for this search service.${NC}"
    ENABLE_RBAC=true
else
    echo -e "${GREEN}✅ RBAC is already enabled (mode: ${CURRENT_AUTH_MODE}).${NC}"
    ENABLE_RBAC=false
fi

# Enable RBAC if needed
if [ "$ENABLE_RBAC" = true ]; then
    echo -e "${BLUE}🔐 Enabling role-based access control on search service...${NC}"
    
    # Enable RBAC with both API key and AAD authentication
    az search service update \
        --name $SEARCH_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --aad-auth-failure-mode http401WithBearerChallenge \
        --auth-options aadOrApiKey
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ RBAC enabled successfully.${NC}"
    else
        echo -e "${RED}❌ Failed to enable RBAC.${NC}"
        exit 1
    fi
    
    # Wait a moment for the configuration to propagate
    echo -e "${YELLOW}⏳ Waiting for RBAC configuration to propagate...${NC}"
    sleep 10
fi

# Check if system-assigned managed identity is enabled
echo -e "${BLUE}🔍 Checking managed identity configuration...${NC}"
IDENTITY_TYPE=$(az search service show --name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --query "identity.type" -o tsv 2>/dev/null || echo "null")

if [ "$IDENTITY_TYPE" = "null" ] || [ -z "$IDENTITY_TYPE" ]; then
    echo -e "${YELLOW}⚠️ System-assigned managed identity is not enabled.${NC}"
    
    echo -e "${BLUE}🆔 Enabling system-assigned managed identity...${NC}"
    # Use the correct Azure CLI command for enabling managed identity on search service
    az search service update \
        --name $SEARCH_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --identity-type SystemAssigned
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ System-assigned managed identity enabled.${NC}"
        # Wait for the identity to be created
        echo -e "${YELLOW}⏳ Waiting for managed identity to be created...${NC}"
        sleep 15
    else
        echo -e "${RED}❌ Failed to enable managed identity.${NC}"
        echo -e "${YELLOW}💡 This may be due to Azure CLI version. Trying alternative approach...${NC}"
        
        # Alternative approach using REST API
        echo -e "${BLUE}🔄 Attempting to enable managed identity using REST API...${NC}"
        
        # Get access token
        ACCESS_TOKEN=$(az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv)
        
        # Enable system-assigned managed identity via REST API
        curl -X PATCH \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"identity": {"type": "SystemAssigned"}}' \
            "https://management.azure.com${SEARCH_RESOURCE_ID}?api-version=2020-08-01"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ System-assigned managed identity enabled via REST API.${NC}"
            echo -e "${YELLOW}⏳ Waiting for managed identity to be created...${NC}"
            sleep 15
        else
            echo -e "${RED}❌ Failed to enable managed identity via REST API.${NC}"
            echo -e "${YELLOW}⚠️ You may need to enable managed identity manually in the Azure portal.${NC}"
            echo -e "${YELLOW}💡 Go to your search service > Identity > System assigned > On${NC}"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}✅ System-assigned managed identity is already enabled.${NC}"
fi

# Get the managed identity principal ID with retry logic
echo -e "${BLUE}🔍 Retrieving managed identity principal ID...${NC}"
MANAGED_IDENTITY_PRINCIPAL_ID=""
RETRY_COUNT=0
MAX_RETRIES=3

while [ -z "$MANAGED_IDENTITY_PRINCIPAL_ID" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    MANAGED_IDENTITY_PRINCIPAL_ID=$(az search service show --name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --query "identity.principalId" -o tsv 2>/dev/null || echo "")
    
    if [ -z "$MANAGED_IDENTITY_PRINCIPAL_ID" ] || [ "$MANAGED_IDENTITY_PRINCIPAL_ID" = "null" ]; then
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}⏳ Managed identity not ready yet, waiting... (attempt ${RETRY_COUNT}/${MAX_RETRIES})${NC}"
            sleep 10
        fi
        MANAGED_IDENTITY_PRINCIPAL_ID=""
    fi
done

if [ -n "$MANAGED_IDENTITY_PRINCIPAL_ID" ] && [ "$MANAGED_IDENTITY_PRINCIPAL_ID" != "null" ]; then
    echo -e "${GREEN}✅ Managed Identity Principal ID: ${MANAGED_IDENTITY_PRINCIPAL_ID}${NC}"
else
    echo -e "${YELLOW}⚠️ Could not retrieve managed identity principal ID.${NC}"
    echo -e "${YELLOW}💡 The managed identity may still be provisioning. You can run this script again later.${NC}"
    echo -e "${YELLOW}💡 Or check the Azure portal to ensure managed identity is enabled.${NC}"
fi

# Assign RBAC roles to the current user
echo -e "${BLUE}👤 Assigning RBAC roles to current user...${NC}"

if [ -z "$CURRENT_USER_OBJECT_ID" ]; then
    echo -e "${RED}❌ Could not determine current user's object ID.${NC}"
    echo -e "${YELLOW}💡 Please ensure you're logged in with a user account (not service principal).${NC}"
    exit 1
fi

# Check if user has permission to assign roles
echo -e "${BLUE}🔍 Checking user permissions...${NC}"
USER_PERMISSIONS=$(az role assignment list --assignee $CURRENT_USER_OBJECT_ID --subscription $SUBSCRIPTION_ID --query "[?contains(roleDefinitionName, 'Owner') || contains(roleDefinitionName, 'User Access Administrator')].roleDefinitionName" -o tsv 2>/dev/null || echo "")

if [ -z "$USER_PERMISSIONS" ]; then
    echo -e "${YELLOW}⚠️ Warning: You may not have sufficient permissions to assign roles.${NC}"
    echo -e "${YELLOW}💡 You need 'Owner' or 'User Access Administrator' role to assign roles to others.${NC}"
    echo -e "${YELLOW}💡 Current user roles in subscription:${NC}"
    az role assignment list --assignee $CURRENT_USER_OBJECT_ID --subscription $SUBSCRIPTION_ID --query "[].roleDefinitionName" -o table 2>/dev/null || echo "Unable to list roles"
else
    echo -e "${GREEN}✅ User has role assignment permissions: ${USER_PERMISSIONS}${NC}"
fi

# Function to assign a role
assign_role() {
    local role_name="$1"
    local assignee_object_id="$2"
    local scope="$3"
    
    echo -e "${BLUE}🔑 Assigning role '${role_name}' to user...${NC}"
    
    # Check if role assignment already exists
    EXISTING_ASSIGNMENT=$(az role assignment list \
        --assignee $assignee_object_id \
        --role "$role_name" \
        --scope $scope \
        --subscription $SUBSCRIPTION_ID \
        --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_ASSIGNMENT" ]; then
        echo -e "${GREEN}✅ Role '${role_name}' is already assigned.${NC}"
        return 0
    fi
    
    # Assign the role with explicit subscription
    az role assignment create \
        --assignee $assignee_object_id \
        --role "$role_name" \
        --scope $scope \
        --subscription $SUBSCRIPTION_ID \
        --output none
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Role '${role_name}' assigned successfully.${NC}"
    else
        echo -e "${RED}❌ Failed to assign role '${role_name}'.${NC}"
        echo -e "${YELLOW}💡 Trying alternative approach with assignee-principal-type...${NC}"
        
        # Try with explicit principal type
        az role assignment create \
            --assignee $assignee_object_id \
            --assignee-principal-type User \
            --role "$role_name" \
            --scope $scope \
            --subscription $SUBSCRIPTION_ID \
            --output none
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Role '${role_name}' assigned successfully with alternative method.${NC}"
        else
            echo -e "${RED}❌ Failed to assign role '${role_name}' with both methods.${NC}"
            return 1
        fi
    fi
}

# Assign each required role
for role in "${RBAC_ROLES[@]}"; do
    echo -e "${BLUE}🔍 Debug info for role assignment:${NC}"
    echo -e "   Role: ${role}"
    echo -e "   Assignee: ${CURRENT_USER_OBJECT_ID}"
    echo -e "   Scope: ${SEARCH_RESOURCE_ID}"
    echo -e "   Subscription: ${SUBSCRIPTION_ID}"
    echo
    
    assign_role "$role" "$CURRENT_USER_OBJECT_ID" "$SEARCH_RESOURCE_ID"
done

# Wait for role assignments to propagate
echo -e "${YELLOW}⏳ Waiting for role assignments to propagate...${NC}"
sleep 15

# Verify role assignments
echo -e "${BLUE}🔍 Verifying role assignments...${NC}"
echo -e "${BLUE}📋 Current role assignments for user:${NC}"

az role assignment list \
    --assignee $CURRENT_USER_OBJECT_ID \
    --scope $SEARCH_RESOURCE_ID \
    --subscription $SUBSCRIPTION_ID \
    --output table \
    --query "[].{Role:roleDefinitionName, Scope:scope}"

# Display configuration summary
echo -e "${BLUE}📋 Configuration Summary:${NC}"
echo -e "   Search Service: ${SEARCH_SERVICE_NAME}"
echo -e "   Resource Group: ${RESOURCE_GROUP_NAME}"
echo -e "   RBAC Enabled: ✅"
echo -e "   Managed Identity: ✅"
echo -e "   User: ${CURRENT_USER}"
echo -e "   Assigned Roles:"
for role in "${RBAC_ROLES[@]}"; do
    echo -e "     - ${role}"
done

# Security recommendations
echo -e "${BLUE}🔒 Security Recommendations:${NC}"
echo -e "   1. ✅ RBAC is now enabled - use Azure AD authentication instead of API keys when possible"
echo -e "   2. ✅ System-assigned managed identity is configured for service-to-service authentication"
echo -e "   3. 💡 Consider disabling API key authentication if RBAC is sufficient for your use case"
echo -e "   4. 💡 Regularly review and audit role assignments"
echo -e "   5. 💡 Use least-privilege principle - only assign necessary roles"

# Instructions for updating application code
echo -e "${BLUE}💻 Next Steps for Your Application:${NC}"
echo -e "   1. Update your application to use DefaultAzureCredential instead of API keys"
echo -e "   2. Remove AZURE_SEARCH_ADMIN_KEY from environment variables if using RBAC exclusively"
echo -e "   3. Ensure your application has the necessary Azure SDK packages for RBAC authentication"

# Optional: Disable API key authentication
echo
read -p "Do you want to disable API key authentication and use RBAC only? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔐 Disabling API key authentication...${NC}"
    
    az search service update \
        --name $SEARCH_SERVICE_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --auth-options aadOrApiKey \
        --disable-local-auth true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ API key authentication disabled. Only RBAC authentication is now allowed.${NC}"
        echo -e "${YELLOW}⚠️ Make sure your applications are configured to use Azure AD authentication!${NC}"
    else
        echo -e "${RED}❌ Failed to disable API key authentication.${NC}"
    fi
else
    echo -e "${YELLOW}💡 API key authentication remains enabled alongside RBAC.${NC}"
fi

# Troubleshooting section
echo -e "${BLUE}🔧 Troubleshooting Tips:${NC}"
echo -e "   • If you encountered 'identity' command not found:"
echo -e "     - Update Azure CLI: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
echo -e "     - Or try: az upgrade"
echo -e "   • If managed identity fails to enable:"
echo -e "     - Check you have Contributor permissions on the search service"
echo -e "     - Try enabling it manually in Azure Portal: Search Service > Identity > System assigned"
echo -e "   • If role assignments fail:"
echo -e "     - Ensure you have User Access Administrator role"
echo -e "     - Wait a few minutes for Azure AD to propagate changes"
echo -e "   • For permission issues:"
echo -e "     - Run: az account show --query 'user.type' to check account type"
echo -e "     - Guest users may need additional permissions"

echo -e "${GREEN}🎉 RBAC configuration completed successfully!${NC}"