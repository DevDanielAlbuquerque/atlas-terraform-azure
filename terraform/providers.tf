provider "azurerm" {
  features {}

  resource_provider_registrations = "none" # Desativa o registro automático de providers

  # Assinatura definida pela variável ARM_SUBSCRIPTION_ID
}
