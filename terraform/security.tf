# Application Security Group

resource "azurerm_application_security_group" "asg_api" {
  name                = "asg-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# NSG - Banco de dados

resource "azurerm_network_security_group" "nsg_banco" {
  name                = "nsg-${local.prefixo}-banco"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Permite PostgreSQL somente a partir do ASG da API
resource "azurerm_network_security_rule" "regra_permitir_api_postgresql" {
  name                        = "permitir-api-postgresql"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_banco.name

  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_application_security_group_ids = [
    azurerm_application_security_group.asg_api.id
  ]

  source_port_range          = "*"
  destination_address_prefix = var.subnet_cidr_banco
  destination_port_range     = "5432"
}

# Bloqueia PostgreSQL das demais origens, inclusive da VNet
resource "azurerm_network_security_rule" "regra_negar_postgresql" {
  name                        = "negar-postgresql-demais"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_banco.name

  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "Tcp"

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_address_prefix = var.subnet_cidr_banco
  destination_port_range     = "5432"
}

resource "azurerm_subnet_network_security_group_association" "associacao_nsg_banco" {
  subnet_id                 = azurerm_subnet.sub_rede_banco.id
  network_security_group_id = azurerm_network_security_group.nsg_banco.id
}

# NSG - Aplicação

resource "azurerm_network_security_group" "nsg_api" {
  name                = "nsg-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Permite SSH somente dos IPs autorizados
resource "azurerm_network_security_rule" "regra_permitir_ssh_admin" {
  name                        = "permitir-ssh-admin"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_api.name

  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefixes    = var.ssh_allowed_cidrs
  source_port_range          = "*"
  destination_address_prefix = var.subnet_cidr_api
  destination_port_range     = "22"
}

# Bloqueia SSH das demais origens
resource "azurerm_network_security_rule" "regra_negar_ssh_demais" {
  name                        = "negar-ssh-demais"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_api.name

  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "Tcp"

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_address_prefix = var.subnet_cidr_api
  destination_port_range     = "22"
}

resource "azurerm_subnet_network_security_group_association" "associacao_nsg_api" {
  subnet_id                 = azurerm_subnet.sub_rede_api.id
  network_security_group_id = azurerm_network_security_group.nsg_api.id
}

# Associação da NIC ao ASG

resource "azurerm_network_interface_application_security_group_association" "nic_api_asg" {
  network_interface_id          = azurerm_network_interface.nic_api.id
  application_security_group_id = azurerm_application_security_group.asg_api.id
}