# Projeto e ambiente

variable "project" {
  description = "Nome base do projeto."
  type        = string
  default     = "atlas"
}

variable "ambiente" {
  description = "Ambiente do projeto"
  type        = string
  default     = "prd"

  validation {
    condition     = var.ambiente == "prd"
    error_message = "O Atlas suporta apenas o ambiente prd."
  }
}

variable "location" {
  description = "Região de implantação dos recursos."
  type        = string
  default     = "eastus2"
}

# Rede

variable "vnet_cidr" {
  description = "Faixa de endereços da VNet."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "Informe um CIDR válido para a VNet."
  }
}

variable "subnet_cidr_api" {
  description = "Faixa de endereços da subnet da API."
  type        = string
  default     = "10.20.2.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr_api, 0))
    error_message = "Informe um CIDR válido para a subnet da API."
  }
}

variable "subnet_cidr_banco" {
  description = "Faixa de endereços da subnet do banco."
  type        = string
  default     = "10.20.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr_banco, 0))
    error_message = "Informe um CIDR válido para a subnet do banco."
  }
}

# Segurança

variable "ssh_allowed_cidrs" {
  description = "Lista de endereços IPv4 autorizados via SSH."
  type        = list(string)

  validation {
    condition = (
      length(var.ssh_allowed_cidrs) > 0 &&
      alltrue([
        for cidr in var.ssh_allowed_cidrs :
        can(cidrhost(cidr, 0)) &&
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/32$", cidr))
      ])
    )

    error_message = "Informe pelo menos um endereço IPv4 válido no formato x.x.x.x/32."
  }
}

# Computação

variable "vm_size" {
  description = "SKU da máquina virtual."
  type        = string
  default     = "Standard_D2als_v6"
}

variable "admin_username" {
  description = "Usuário administrador da VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Caminho da chave SSH pública."
  type        = string
  default     = "~/.ssh/atlas-dev.pub"
}