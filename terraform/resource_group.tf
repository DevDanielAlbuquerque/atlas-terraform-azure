resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.prefixo}"
  location = var.location
  tags     = local.tags
}