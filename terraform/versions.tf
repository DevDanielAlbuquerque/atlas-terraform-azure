terraform {
  required_version = ">= 1.5" # Versão mínima do Terraform

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # Permite apenas versões 4.x
    }
  }
}