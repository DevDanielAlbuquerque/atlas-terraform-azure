# IP público

resource "azurerm_public_ip" "ip_publico_api" {
  name                = "pip-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# Interface de rede

resource "azurerm_network_interface" "nic_api" {
  name                = "nic-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig-${local.prefixo}-api"
    subnet_id                     = azurerm_subnet.sub_rede_api.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip_publico_api.id
  }
}

# Interface de rede

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.prefixo}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

# Subnets

resource "azurerm_subnet" "sub_rede_api" {
  name                 = "snet-${local.prefixo}-api"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr_api]
}

resource "azurerm_subnet" "sub_rede_banco" {
  name                 = "snet-${local.prefixo}-banco"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr_banco]
}