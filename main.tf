data "azurerm_client_config" "current" {
}

locals {
  resource_group_name = "function-app-rg"
  location            = "australiaeast"
  tags = {
    created_by  = "terraform"
    environment = "dev"
  }
}
################################################################################
# Function App Storage Account
################################################################################
resource "azurerm_storage_account" "function_app_storage_account" {
  name                            = "masonfateststore00000001"
  resource_group_name             = local.resource_group_name
  location                        = local.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  shared_access_key_enabled       = true
  default_to_oauth_authentication = true
  public_network_access_enabled   = true
  tags                            = local.tags
}

resource "azurerm_storage_container" "app_code" {
  name                  = "app-code"
  storage_account_id    = azurerm_storage_account.function_app_storage_account.id
  container_access_type = "private"
  depends_on            = [azurerm_storage_account.function_app_storage_account]
}

################################################################################
# Monitoring and Logging for function app
################################################################################
resource "azurerm_log_analytics_workspace" "function_app" {
  name                = "law-function-app-1"
  location            = local.location
  resource_group_name = local.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = local.tags
}

resource "azurerm_application_insights" "function_app" {
  name                 = "ai-function-app-1"
  location             = local.location
  resource_group_name  = local.resource_group_name
  workspace_id         = azurerm_log_analytics_workspace.function_app.id
  application_type     = "web"
  daily_data_cap_in_gb = 1
  retention_in_days    = 30
  sampling_percentage  = 100
  tags                 = local.tags
}

################################################################################
# Managed Identity
################################################################################
resource "azurerm_user_assigned_identity" "default_mi" {
  location            = local.location
  resource_group_name = local.resource_group_name
  name                = "default-mi"
  tags                = local.tags
}

resource "azurerm_role_assignment" "blob_data_contributor_shared_storage" {
  scope                = azurerm_storage_account.function_app_storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
}

################################################################################
# Function App
################################################################################
resource "azurerm_service_plan" "asp" {
  name                = "asp-1"
  resource_group_name = local.resource_group_name
  location            = local.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azapi_resource" "function_app" {
  type      = "Microsoft.Web/sites@2024-04-01"
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}"
  location  = local.location
  name      = "fa-masontest-0000000001"
  tags      = local.tags
  body = {
    kind = "functionapp,linux"
    identity = {
      type = "UserAssigned" # Or "SystemAssigned" => If "SystemAssigned" remove the userAssignedIdentites {} block
      userAssignedIdentities = {
        "${azurerm_user_assigned_identity.default_mi.id}" = {}
      }
    }
    properties = {
      serverFarmId = azurerm_service_plan.asp.id
      functionAppConfig = {
        deployment = {
          storage = {
            type  = "blobcontainer",
            value = "https://${azurerm_storage_account.function_app_storage_account.name}.blob.core.windows.net/${azurerm_storage_container.app_code.name}",
            authentication = {
              type                           = "userassignedidentity" # Or "systemassignedidentity" => If "systemassignedidentity" remove "userAssigned... =" below. 
              userAssignedIdentityResourceId = azurerm_user_assigned_identity.default_mi.id
            }
          }
        },
        scaleAndConcurrency = {
          alwaysReady = [
            {
              instanceCount = 2
              name          = "http"
            }
          ]
          maximumInstanceCount = 40,
          instanceMemoryMB     = 2048,
          triggers = {
            http = {
              perInstanceConcurrency = 750
            }
          }
        },
        runtime = {
          name    = "dotnet-isolated"
          version = "8.0"
        }
      },
      siteConfig = {
        appSettings = [
          {
            name  = "AzureWebJobsStorage__accountName",
            value = azurerm_storage_account.function_app_storage_account.name
          },
          {
            name  = "AzureWebJobsStorage__credential",
            value = "managedidentity"
          },
          {
            name  = "AzureWebJobsStorage__clientId",
            value = azurerm_user_assigned_identity.default_mi.client_id
          },
          {
            name  = "APPLICATIONINSIGHTS_CONNECTION_STRING",
            value = azurerm_application_insights.function_app.connection_string
          }
        ]
      }
    }
  }
  depends_on = [azurerm_storage_container.app_code, azurerm_service_plan.asp]
}
