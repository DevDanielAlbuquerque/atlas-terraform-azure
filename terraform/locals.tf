locals {
  prefixo = "${var.project}-${var.ambiente}" # Prefixo padrão dos recursos

  tags = {
    projeto    = var.project
    ambiente   = var.ambiente
    gerenciado = "terraform"
  }
}