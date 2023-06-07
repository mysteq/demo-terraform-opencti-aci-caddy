terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.56.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstatedemoopenctiakscaddy"
    storage_account_name = "tfstatedemoopencti54355"
    container_name       = "tfstatedemoopenctiakscaddy"
    key                  = "tfstatedemoopenctiakscaddy.tfstate"
    subscription_id      = "ad3a592d-2f32-4013-8b6a-a290a0aafed2"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "ad3a592d-2f32-4013-8b6a-a290a0aafed2"
}

provider "azurerm" {
  features {}
  alias           = "dns"
  subscription_id = "646dcda3-7645-475b-8dc3-be6257586e68"
}
