terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.12.0"
    }
  }
}

provider "azapi" {
}

provider "azurerm" {
  # export ARM_SUBSCRIPTION_ID
  features {}
}
