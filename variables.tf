# ============================================================
# VARIÁVEIS = os "botões" do projeto.
# Mudou o valor aqui (ou no terraform.tfvars), mudou em tudo.
# ============================================================
variable "project" {
  description = "Nome base do projeto, usado na composição dos nomes dos recursos."
  type        = string
  default     = "atlas"
}
variable "ambiente" {
  description = "Ambiente de implantação, por exemplo dev, hml ou prd."
  type        = string
  default     = "prd"
}
variable "location" {
  description = "Região do Azure onde os recursos serão criados."
  type        = string
  default     = "eastus2"
}

variable "vnet_cidr" {
  description = "Faixa de endereços da VNet."
  type        = string
  default     = "10.20.0.0/16"
}
variable "subnet_cidr_api" {
  description = "Faixa de endereços da sub-rede da API. Deve estar dentro de vnet_cidr."
  type        = string
  default     = "10.20.2.0/24"
}
variable "subnet_cidr_banco" {
  description = "Faixa de endereços da sub-rede do banco. Deve estar dentro de vnet_cidr e não sobrepor subnet_cidr_api."
  type        = string
  default     = "10.20.1.0/24"
}

variable "ssh_allowed_cidrs" {
  description = "Lista de IPs públicos autorizados a acessar a VM por SSH, no formato IPv4/32."
  type        = list(string)

  validation {
    condition = (
      length(var.ssh_allowed_cidrs) > 0 &&
      alltrue([
        for cidr in var.ssh_allowed_cidrs :
        can(cidrhost(cidr, 0)) &&
        endswith(cidr, "/32") &&
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/32$", cidr))
      ])
    )

    error_message = "Informe pelo menos um endereço IPv4 válido no formato x.x.x.x/32."
  }
}

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
  description = "Caminho da chave SSH pública (.pub) autorizada na VM. Informe no terraform.tfvars. Aceita ~ no início do caminho."
  type        = string
  default     = "~/.ssh/atlas-dev.pub"
}