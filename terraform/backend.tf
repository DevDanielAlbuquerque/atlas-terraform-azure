terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfatlasad5155ee"
    container_name       = "tfstate"
    key                  = "atlas-prd.tfstate" # State do ambiente PRD

    use_azuread_auth = true # Autenticação via Microsoft Entra ID
  }
}