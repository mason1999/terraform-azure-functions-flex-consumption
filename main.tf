data "azurerm_client_config" "current" {
}

locals {
  resource_group_name = "webapp-rg"
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
  name                            = "masonteststore0000000000"
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
# Managed Identity
################################################################################
# resource "azurerm_user_assigned_identity" "default_mi" {
#   location            = local.location
#   resource_group_name = local.resource_group_name
#   name                = "default-mi"
#   tags                = local.tags
# }

# resource "azurerm_role_assignment" "blob_data_contributor_shared_storage" {
#   scope                = azurerm_storage_account.function_app_storage_account.id
#   role_definition_name = "Storage Blob Data Owner"
#   principal_id         = azurerm_user_assigned_identity.default_mi.principal_id
# }

################################################################################
# Function App 
################################################################################
resource "azurerm_service_plan" "asp" {
  name                = "asp"
  resource_group_name = local.resource_group_name
  location            = local.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azapi_resource" "functionApps" {
  type      = "Microsoft.Web/sites@2024-04-01"
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.resource_group_name}"
  location  = local.location
  name      = "fa-masontest-0000000000"
  tags      = local.tags
  body = {
    kind = "functionapp,linux"
    identity = {
      type = "SystemAssigned"
      # type = "UserAssigned"
      # userAssignedIdentities = {
      #   "${azurerm_user_assigned_identity.default_mi.id}" = {}
      # }
    }
    properties = {
      serverFarmId = azurerm_service_plan.asp.id
      functionAppConfig = {
        deployment = {
          storage = {
            type  = "blobContainer",
            value = "https://${azurerm_storage_account.function_app_storage_account.name}.blob.core.windows.net/${azurerm_storage_container.app_code.name}",
            authentication = {
              type = "SystemAssignedIdentity"
              # type                           = "UserAssignedIdentity"
              # userAssignedIdentityResourceId = azurerm_user_assigned_identity.default_mi.id
            }
          }
        },
        scaleAndConcurrency = {
          alwaysReady = [
            {
              instanceCount = 5
              name          = "blob"
            }
          ]
          maximumInstanceCount = 40,
          instanceMemoryMB     = 2048,
          triggers = {
            http = {
              perInstanceConcurrency = 3
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
          } #,
          # {
          #   name  = "AzureWebJobsStorage__cliendId",
          #   value = azurerm_user_assigned_identity.default_mi.client_id
          # }
        ]
      }
    }
  }
  depends_on = [azurerm_storage_container.app_code, azurerm_service_plan.asp]
}

# TODO: figure out authentication
data "azurerm_linux_function_app" "fn_wrapper" {
  name                = azapi_resource.functionApps.name
  resource_group_name = local.resource_group_name
}


resource "azurerm_role_assignment" "blob_data_contributor_shared_storage_1" {
  scope                = azurerm_storage_account.function_app_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_linux_function_app.fn_wrapper.identity.0.principal_id
}
