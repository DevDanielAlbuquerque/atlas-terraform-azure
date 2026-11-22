# ============================================================
# CONFIGURAÇÃO DO TERRAFORM E DO PROVIDER
# ============================================================

terraform {
  # Versão mínima do Terraform exigida pelo projeto.
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"

      # Aceita versões 4.x. Atualizações para versões novas devem ser revisadas e testadas antes.
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Bloco obrigatório no azurerm, mesmo sem opções.
  features {}

  # Não registra automaticamente os resource providers na assinatura.
  resource_provider_registrations = "none"

  # O ID da assinatura vem da variável de ambiente ARM_SUBSCRIPTION_ID.
}

# ============================================================
# LOCALS: valores calculados internamente.
# Diferente de variables.tf, que recebe valores de fora.
# ============================================================

locals {
  # Prefixo padrão dos nomes: "<projeto>-<ambiente>".
  prefixo = "${var.project}-${var.ambiente}"

  # Tags ajudam a identificar recursos e atribuir custos.
  # Não reduzem gastos nem criam limites de orçamento.
  tags = {
    projeto    = var.project
    ambiente   = var.ambiente
    gerenciado = "terraform"
  }
}
