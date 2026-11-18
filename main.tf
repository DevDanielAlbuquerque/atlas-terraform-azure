# ============================================================
# CONFIGURAÇÃO DO TERRAFORM
# ============================================================

terraform {
  # Define a versão mínima do Terraform permitida para executar este projeto.
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      # Origem do plugin no Terraform Registry (namespace/nome).
      source = "hashicorp/azurerm"

      # Permite versões do provider a partir de 4.0 e abaixo de 5.0. Atualizações ainda precisam ser revisadas e testadas.
      version = "~> 4.0"
    }
  }
}

# Bloco obrigatório de configuração de comportamentos do AzureRM; vazio, mantém os padrões dessas opções
provider "azurerm" {
    
    features {}
    
    # Desativa o registro automático de serviços na assinatura Azure   
    resource_provider_registrations = "none"

  # IMPORTANTE: no azurerm 4.x o ID da assinatura é obrigatório.
  # Opção 1 (recomendada): export ARM_SUBSCRIPTION_ID="xxxx-xxxx-xxxx"
  # Opção 2: descomentar a linha abaixo
  # subscription_id = "xxxx-xxxx-xxxx"

}

# ============================================================
# LOCALS = variáveis internas calculadas, evitam repetição.
# variáveis.tf é para variáveis externas, que podem ser alteradas de fora.
# ============================================================

locals {

  # tags ajudam a identificar recursos e atribuir custos. Elas não reduzem gastos nem criam limites de orçamento.
  tags = {
    projeto    = var.project
    ambiente   = var.ambiente
    gerenciado = "terraform"

  }
}

resource "azurerm_resource_group" "rg" {
  #agora usamos o prefixo rg-, seguido de projeto e ambiente; o comentário ainda menciona sufixo.
  name     = "rg-${var.project}-${var.ambiente}" 
  location = var.location 
  tags     = local.tags # Tags aplicadas ao grupo de recursos, definidas em "locals.tags"
}

# ============================================================
# REDE VIRTUAL (VNet)
# Ao usar azurerm_resource_group.rg.location, o Terraform entende
# que o RG precisa existir ANTES. Isso é uma dependência implícita.
# ============================================================
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project}-${var.ambiente}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr] # Faixa de endereços da VNet, definida na variável var.vnet_cidr
  tags                = local.tags
}

# ============================================================
# SUB-REDE - Um "pedaço" da VNet onde a VM vai ficar.
# ============================================================

# Sub-rede da aplicação 
resource "azurerm_subnet" "app_subnet" {
  name                 = "snet-${var.project}-${var.ambiente}-app" # Nome da sub-rede, composto pelo prefixo "snet-", seguido de projeto, ambiente e sufixo "-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr_app] # Faixa de endereços da sub-rede, definida na variável var.subnet_cidr_app
}

# Sub-rede do banco
resource "azurerm_subnet" "banco_subnet" {
  name                 = "snet-${var.project}-${var.ambiente}-banco" # Nome da sub-rede, composto pelo prefixo "snet-", seguido de projeto, ambiente e sufixo "-banco"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr_banco] # Faixa de endereços da sub-rede, definida na variável var.subnet_cidr_banco
}

# ============================================================
# GRUPO DE SEGURANÇA DE APLICATIVO (ASG) e GRUPO DE SEGURANÇA DE REDE (NSG)
# ============================================================

# O ASG é um grupo lógico de VMs que compartilham regras de segurança. Ele não cria regras, mas permite que você agrupe VMs e aplique regras de NSG a esse grupo.
resource "azurerm_application_security_group" "asg" {
  name                = "asg-${var.project}-${var.ambiente}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# O NSG é um grupo de regras de segurança que controla o tráfego de rede para recursos do Azure. Ele pode ser associado a sub-redes ou interfaces de rede (NICs) para aplicar suas regras.
resource "azurerm_network_security_group" "banco_nsg" {
  name                = "nsg-${var.project}-${var.ambiente}-banco"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# ============================================================
# REGRAS DE SEGURANÇA DE REDE (NSG RULES)
# ============================================================

# A regra abaixo permite conexões TCP à porta 5432 (PostgreSQL) somente de VMs associadas ao ASG da API, que estão na sub-rede da aplicação. Isso garante que apenas a aplicação possa acessar o banco de dados.
resource "azurerm_network_security_rule" "banco_nsg_rule" {
  name                        = "allow-api-postgresql"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.banco_nsg.name

  # Números menores são avaliados primeiro.
  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  # Permite somente as interfaces associadas ao ASG da API.
  source_application_security_group_ids = [
    azurerm_application_security_group.asg.id
  ]

  # A aplicação pode usar uma porta temporária na origem.
  source_port_range = "*"

  # Destino: sub-rede do banco, na porta do PostgreSQL.
  destination_address_prefix = var.subnet_cidr_banco
  destination_port_range     = "5432"
}

# Bloqueia conexões TCP à porta 5432 que não foram
# permitidas pela regra anterior, de prioridade 100.
resource "azurerm_network_security_rule" "bloquear_postgresql" {
  name                        = "deny-other-postgresql"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.banco_nsg.name

  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "Tcp"

  source_address_prefix = "*"
  source_port_range     = "*"

  destination_address_prefix = var.subnet_cidr_banco
  destination_port_range     = "5432"
}

# Associa o NSG à sub-rede do banco para aplicar suas regras.
resource "azurerm_subnet_network_security_group_association" "banco" {
  subnet_id                 = azurerm_subnet.banco_subnet.id
  network_security_group_id = azurerm_network_security_group.banco_nsg.id
}

# ============================================================
# INTERFACE DE REDE (NIC) PARA A VM DA APLICAÇÃO
# ============================================================

# A interface de rede (NIC) é o ponto de conexão da VM à rede virtual. Ela recebe um endereço IP da sub-rede da aplicação e pode ser associada a regras de segurança.
resource "azurerm_network_interface" "app_nic" {
  name                = "nic-${var.project}-${var.ambiente}-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  # Configura o IP privado da NIC e a conecta à sub-rede da aplicação. 
  ip_configuration {
    name                          = "ipconfig-${var.project}-${var.ambiente}-app"
    subnet_id                     = azurerm_subnet.app_subnet.id
    public_ip_address_id          = azurerm_public_ip.app_public_ip.id
    private_ip_address_allocation = "Dynamic"
    
  }
}

# Associa a NIC ao ASG da API, permitindo que as regras do NSG
# identifiquem essa interface como integrante do grupo.
resource "azurerm_network_interface_application_security_group_association" "app_nic_association" {
  network_interface_id          = azurerm_network_interface.app_nic.id
  application_security_group_id = azurerm_application_security_group.asg.id
}


# ============================================================
# NSG PARA APLICATIVO E REGRAS DE SEGURANÇA DO APP
# ============================================================

# Cria o NSG que reunirá as regras de segurança da aplicação.
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-${var.project}-${var.ambiente}-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Cria a regra que permite acesso administrativo por SSH.
resource "azurerm_network_security_rule" "app_nsg_rule" {
  name                        = "allow-api-ssh"
  resource_group_name         = azurerm_resource_group.rg.name

  # Define a qual NSG esta regra pertence.
  network_security_group_name = azurerm_network_security_group.app_nsg.name

  # Números menores são avaliados primeiro. # A primeira regra que corresponder ao tráfego determina a ação.
  priority  = 100
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  # Origem: IP público autorizado para administrar a VM.
  # Permite SSH a partir do IP público autorizado, definido com /32.
  source_address_prefix = var.ssh_allowed_cidr

  # O cliente SSH pode usar uma porta temporária na origem.
  source_port_range = "*"

  # Destino: endereços privados da sub-rede da aplicação.
  destination_address_prefix = var.subnet_cidr_app
  destination_port_range     = "22"
}
 
resource "azurerm_network_security_rule" "bloquear_ssh" {
  name                        = "deny-other-ssh"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.app_nsg.name

  priority  = 200
  direction = "Inbound"
  access    = "Deny"
  protocol  = "Tcp"

  source_address_prefix = "*"
  source_port_range     = "*"

  destination_address_prefix = var.subnet_cidr_app
  destination_port_range     = "22"
}

# Associa o NSG à sub-rede da aplicação.
 # Esse vínculo faz as regras do NSG serem aplicadas ao tráfego
 # dos recursos conectados a essa sub-rede.
 resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg" {
  subnet_id                 = azurerm_subnet.app_subnet.id   # Sub-rede que será protegida.
  network_security_group_id = azurerm_network_security_group.app_nsg.id  # NSG cujas regras serão aplicadas.
}

resource "azurerm_public_ip" "app_public_ip" {
  name                = "pip-${var.project}-${var.ambiente}-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
  sku               = "Standard"
  tags                = local.tags
}


#######################################################
#####################Validar###########################

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "vm-${var.project}-${var.ambiente}-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.app_nic.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
  version   = "latest"
}
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }
  tags                = local.tags
}
 