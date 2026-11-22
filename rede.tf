# ============================================================
# GRUPO DE RECURSOS, REDE VIRTUAL E SUB-REDES
# ============================================================

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.prefixo}"
  location = var.location
  tags     = local.tags
}

# Usar azurerm_resource_group.rg nas propriedades cria uma dependência implícita:
# o grupo é criado antes da rede.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.prefixo}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

# Sub-rede da API.
resource "azurerm_subnet" "sub_rede_api" {
  name                 = "snet-${local.prefixo}-api"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr_api]
}

# Sub-rede do banco de dados.
resource "azurerm_subnet" "sub_rede_banco" {
  name                 = "snet-${local.prefixo}-banco"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr_banco]
}