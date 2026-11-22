# ============================================================
# SEGURANÇA DE REDE: ASG, NSGs, REGRAS E ASSOCIAÇÕES
#
# Regras de NSG são avaliadas pela prioridade, do menor para o maior número.
# A primeira regra que corresponder ao tráfego decide a ação.
# ============================================================

# ASG: grupo lógico de interfaces de rede. Não cria regras por si só,
# mas permite usar o grupo como origem ou destino nas regras de NSG.
resource "azurerm_application_security_group" "asg_api" {
  name                = "asg-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# ------------------------------------------------------------
# NSG DO BANCO
# ------------------------------------------------------------

resource "azurerm_network_security_group" "nsg_banco" {
  name                = "nsg-${local.prefixo}-banco"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Permite PostgreSQL (TCP 5432) somente das interfaces do ASG da aplicação.
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

  source_port_range = "*"

  destination_address_prefix = var.subnet_cidr_banco
  destination_port_range     = "5432"
}

# Nega outras origens na porta 5432. Sem esta regra, a regra padrão
# AllowVnetInBound (prioridade 65000) permitiria tráfego de toda a VNet.
resource "azurerm_network_security_rule" "regra_negar_postgresql" {
  name                        = "negar-postgresql-demais"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_banco.name

  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "Tcp"

  source_address_prefix = "*"
  source_port_range     = "*"

  destination_address_prefix = var.subnet_cidr_banco
  destination_port_range     = "5432"
}

# Aplica o NSG do banco à sub-rede do banco.
resource "azurerm_subnet_network_security_group_association" "associacao_nsg_banco" {
  subnet_id                 = azurerm_subnet.sub_rede_banco.id
  network_security_group_id = azurerm_network_security_group.nsg_banco.id
}

# ------------------------------------------------------------
# NSG DA APLICAÇÃO
# ------------------------------------------------------------

resource "azurerm_network_security_group" "nsg_api" {
  name                = "nsg-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Permite SSH somente do IP público autorizado (var.ssh_allowed_cidr, no formato IP/32).
resource "azurerm_network_security_rule" "regra_permitir_ssh_admin" {
  name                        = "permitir-ssh-admin"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_api.name

  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix = var.ssh_allowed_cidr
  source_port_range     = "*"

  destination_address_prefix = var.subnet_cidr_api
  destination_port_range     = "22"
}

# Nega SSH de qualquer outra origem.
resource "azurerm_network_security_rule" "regra_negar_ssh_demais" {
  name                        = "negar-ssh-demais"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_api.name

  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "Tcp"

  source_address_prefix = "*"
  source_port_range     = "*"

  destination_address_prefix = var.subnet_cidr_api
  destination_port_range     = "22"
}

# Aplica o NSG da aplicação à sub-rede da aplicação.
resource "azurerm_subnet_network_security_group_association" "associacao_nsg_api" {
  subnet_id                 = azurerm_subnet.sub_rede_api.id
  network_security_group_id = azurerm_network_security_group.nsg_api.id
}
