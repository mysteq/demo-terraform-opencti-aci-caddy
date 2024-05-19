terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.104.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11.1"
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
  subscription_id = "49a743cb-1b0b-4bbd-9986-f9fcf513526f"
}
