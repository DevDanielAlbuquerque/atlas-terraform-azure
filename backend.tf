terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfatlasad5155ee"
    container_name       = "tfstate"
    key                  = "atlas-prd.tfstate"

    use_azuread_auth = true
  }
}