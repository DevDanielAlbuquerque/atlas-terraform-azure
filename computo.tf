# ============================================================
# COMPUTAÇÃO: IP PÚBLICO, INTERFACE DE REDE E VM DA APLICAÇÃO
# ============================================================

resource "azurerm_public_ip" "ip_publico_api" {
  name                = "pip-${local.prefixo}-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# A NIC é o ponto de conexão da VM à rede. Recebe um IP privado dinâmico
# da sub-rede da aplicação e o IP público estático definido acima.
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

# Associa a NIC ao ASG da aplicação, para que as regras do NSG
# reconheçam esta interface como integrante do grupo.
resource "azurerm_network_interface_application_security_group_association" "nic_api_asg" {
  network_interface_id          = azurerm_network_interface.nic_api.id
  application_security_group_id = azurerm_application_security_group.asg_api.id
}

resource "azurerm_linux_virtual_machine" "vm_api" {
  name                = "vm-${local.prefixo}-api"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.tags

  network_interface_ids = [
    azurerm_network_interface.nic_api.id,
  ]

  # Acesso somente por chave SSH, sem senha.
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

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
}
