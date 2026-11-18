# ============================================================
# VARIÁVEIS = os "botões" do projeto.
# Mudou o valor aqui (ou no terraform.tfvars), mudou em tudo.
# ============================================================

# Variável para o nome do projeto, usada para compor nomes de recursos.
variable "project" {
  description = "Nome base do projeto"
  type        = string
  default     = "atlas"
}

# Variável para o ambiente de implantação, usada para compor nomes de recursos.    
variable "ambiente" {
  description = "Ambiente de implantação."
  type        = string
  default     = "dev"
}

# Variável para a região do Azure onde os recursos serão criados.
variable "location" {
  description = "Região do Azure para criar recursos."
  type        = string
  default     = "eastus2"
}

# Variável para o espaço de endereço da VNet, usada para definir a faixa de IPs da rede virtual.
variable "vnet_cidr"{
  description = "Espaço de endereço da VNet."
  type        = string
  default     = "10.20.0.0/16"
}  

# Variável para o espaço de endereço da sub-rede do banco, usada para definir a faixa de IPs da sub-rede.
variable "subnet_cidr_banco" {
  description = "Espaço de endereço da Sub-rede."
  type        = string
  default     = "10.20.1.0/24"
}

# Variável para o espaço de endereço da sub-rede da aplicação, usada para definir a faixa de IPs da sub-rede.
variable "subnet_cidr_app" {
  description = "Espaço de endereço da Sub-rede."
  type        = string
  default     = "10.20.2.0/24"
}

# Variável para a faixa de IPs permitida para acesso SSH.
variable "ssh_allowed_cidr" {
  description = "IP público autorizado a acessar a VM por SSH, no formato IP/32. Informe no terraform.tfvars."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && endswith(var.ssh_allowed_cidr, "/32")
    error_message = "Use um IP único no formato x.x.x.x/32."
  }
}

#######################################################
#####################Validar###########################

variable "vm_size" {
  description = "Tamanho (SKU) da máquina virtual."
  type        = string
  default     = "Standard_D2als_v6"
}

variable "admin_username" {
  description = "Usuário administrador criado na VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Caminho da chave SSH PÚBLICA (.pub) que será autorizada na VM."
  type        = string
  default     = "~/.ssh/atlas-dev.pub"
}