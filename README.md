# Atlas — Infraestrutura Azure com Terraform

Laboratório de infraestrutura como código para praticar Azure, Linux, redes e fundamentos de operação de ambientes Cloud/SRE.

Esta documentação descreve a **base inicial DEV**, anterior à refatoração: uma VM Ubuntu com acesso SSH por chave, rede segmentada e regras de segurança. A proposta é compreender cada recurso, validar seu comportamento e registrar a evolução do projeto.

> Ambiente de estudo com cenário empresarial simulado. Esta versão não representa uma aplicação em produção nem implementa alta disponibilidade.

## Estado do projeto

| Entrega | Situação nesta versão |
|---|---|
| Grupo de recursos, VNet e duas sub-redes | Implementados |
| NSGs, regras e associações às sub-redes | Implementados |
| ASG da API e associação da NIC | Implementados |
| IP público Standard estático e NIC | Implementados |
| VM Ubuntu 22.04 LTS Gen2 | Implementada |
| Acesso SSH pela origem autorizada | Validado durante o laboratório |
| Bloqueio de SSH por outra rede | Teste prático pendente |
| VM/serviço PostgreSQL e consulta ao banco | Ainda não implementados |
| API C#, monitoramento e backups | Etapas futuras |

O estado acima registra o progresso do laboratório, não uma verificação em tempo real dos recursos na Azure.

## Arquitetura

Configuração padrão: projeto `atlas`, ambiente `dev`, região `eastus2`.

```mermaid
flowchart TD
    ADMIN["Administrador: IPv4 público autorizado /32"]
    subgraph RG["rg-atlas-dev"]
        PIP["pip-atlas-dev-app: IP público Standard"]
        ASG["asg-atlas-dev-api"]
        subgraph VNET["vnet-atlas-dev — 10.20.0.0/16"]
            subgraph APP["snet-atlas-dev-app — 10.20.2.0/24"]
                NIC["nic-atlas-dev-app"]
                VM["vm-atlas-dev-app — Ubuntu 22.04"]
            end
            subgraph DATA["snet-atlas-dev-banco — 10.20.1.0/24"]
                FUTURO["PostgreSQL: ainda não implantado"]
            end
        end
        NSGAPP["nsg-atlas-dev-app"]
        NSGDB["nsg-atlas-dev-banco"]
    end
    ADMIN -->|"SSH TCP 22"| PIP
    PIP --> NIC
    NIC --- VM
    NIC -.->|"associada ao grupo"| ASG
    NSGAPP -.->|"associado à sub-rede"| APP
    NSGDB -.->|"associado à sub-rede"| DATA
    VM -.->|"fluxo futuro: TCP 5432"| FUTURO
```

As linhas de associação representam configuração, não saltos do tráfego. A separação em sub-redes organiza os recursos; o controle de acesso é feito pelas regras dos NSGs.

### Regras implementadas

Todas as regras abaixo são de entrada, usam TCP e permitem qualquer porta de origem.

| NSG | Prioridade | Origem | Destino | Porta de destino | Ação |
|---|---:|---|---|---:|---|
| Aplicação | 100 | `ssh_allowed_cidr` | Sub-rede da aplicação | 22 | Allow |
| Aplicação | 200 | Qualquer origem | Sub-rede da aplicação | 22 | Deny |
| Banco | 100 | ASG da API | Sub-rede do banco | 5432 | Allow |
| Banco | 200 | Qualquer origem | Sub-rede do banco | 5432 | Deny |

A primeira regra correspondente decide a ação. Os bloqueios de prioridade 200 precedem a regra padrão `AllowVNetInBound` de prioridade 65000.

**O bloqueio é específico às portas indicadas.** Esta configuração não bloqueia todo o tráfego entre sub-redes. As demais regras padrão, inclusive as de saída, continuam presentes.

O ASG identifica interfaces de rede; a permissão é definida pelo NSG. Acesso de rede ao PostgreSQL também não substitui autenticação e permissões do banco.

## Decisões desta base

- **Terraform:** infraestrutura declarativa, revisão do plano antes de aplicar e possibilidade de reproduzir o laboratório.
- **Duas sub-redes:** separação entre aplicação e futuro banco.
- **ASG para a API:** regras baseadas na associação da NIC ao grupo, sem fixar o IP privado da aplicação.
- **SSH limitado a um IPv4 /32:** administração por uma origem autorizada, com autenticação por chave.
- **IP público na NIC:** caminho direto para administração neste laboratório, sem VPN ou Bastion nesta etapa.
- **VM `Standard_D2als_v6`:** tamanho configurável; disponibilidade, quota e custo devem ser conferidos na assinatura de destino.
- **Disco `Standard_LRS` e cache `ReadWrite`:** configuração do disco do sistema operacional nesta versão.
- **Estado local:** adequado à etapa inicial de estudo; colaboração e automação exigirão discutir armazenamento remoto, acesso e recuperação do estado.

A API e o PostgreSQL estão planejados para máquinas separadas. Somente a VM da aplicação está declarada nesta versão.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| [main.tf](main.tf) | Provider, tags e todos os recursos da base |
| [variables.tf](variables.tf) | Entradas, defaults e validação da origem SSH |
| [.terraform.lock.hcl](.terraform.lock.hcl) | Versão selecionada e hashes do provider |
| [.gitignore](.gitignore) | Exclusões de estado, arquivos locais e segredos |

Requisito declarado: Terraform **>= 1.5**, AzureRM **~> 4.0**. O lockfile consultado seleciona AzureRM **4.81.0**. Atualizações do provider devem ser revisadas, mesmo dentro da série 4.

## Entradas

| Variável | Padrão | Finalidade |
|---|---|---|
| `project` | `atlas` | Nome base |
| `ambiente` | `dev` | Identificação do ambiente |
| `location` | `eastus2` | Região Azure |
| `vnet_cidr` | `10.20.0.0/16` | Espaço da VNet |
| `subnet_cidr_app` | `10.20.2.0/24` | Sub-rede da aplicação |
| `subnet_cidr_banco` | `10.20.1.0/24` | Sub-rede do banco |
| `ssh_allowed_cidr` | Sem default | IPv4 público autorizado, com /32 |
| `vm_size` | `Standard_D2als_v6` | Tamanho da VM |
| `admin_username` | `azureuser` | Usuário Linux |
| `ssh_public_key_path` | `~/.ssh/atlas-dev.pub` | Arquivo da chave pública |

A validação atual de SSH verifica um CIDR válido terminado em `/32`; ela ainda não verifica explicitamente que o endereço é IPv4 público. Forneça o IPv4 público de saída da sua conexão, não o endereço privado do computador.

## Como executar

As instruções abaixo consideram Linux/WSL, Azure CLI, Git e Terraform instalados, além de uma assinatura com permissões e quota disponíveis.

### 1. Obter o projeto e selecionar a assinatura

```bash
git clone https://github.com/DevDanielAlbuquerque/atlas-terraform-azure.git
cd atlas-terraform-azure

az login
az account set --subscription "<ID_DA_ASSINATURA>"
az account show --query "{nome:name,id:id}" --output table
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

Confira a assinatura antes de continuar. A variável exportada vale para a sessão atual do terminal.

O provider está configurado com `resource_provider_registrations = "none"`. Confirme que `Microsoft.Compute` e `Microsoft.Network` estão registrados na assinatura; se não estiverem, providencie o registro com uma identidade autorizada.

### 2. Preparar o par de chaves SSH

Confira primeiro se o destino já existe:

```bash
ls ~/.ssh
```

Para um novo par, sem sobrescrever uma chave existente:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/atlas-dev
```

Defina uma passphrase para proteger a chave privada. O arquivo `atlas-dev.pub` é lido pelo Terraform; `atlas-dev` permanece no computador e é usado pelo cliente SSH. Não versione a chave privada.

### 3. Informar os valores locais

Crie um arquivo `terraform.tfvars` na pasta do projeto:

```hcl
# EXEMPLO: substitua pelo IPv4 público real da sua conexão.
ssh_allowed_cidr = "203.0.113.10/32"

ssh_public_key_path = "~/.ssh/atlas-dev.pub"
```

O endereço acima é fictício e não autoriza sua conexão real. O arquivo `terraform.tfvars` é ignorado pelo Git. As outras entradas podem ser sobrescritas nele conforme necessário.

### 4. Validar, planejar e aplicar

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

Revise recursos, nomes, região, origem SSH e possíveis destruições antes de confirmar o apply. Um plano bem-sucedido não garante capacidade ou quota disponível na Azure.

Se você já administra um ambiente existente, utilize o diretório e o estado correspondentes. Clonar este repositório **não recupera o estado** nem faz o Terraform reconhecer automaticamente recursos já criados.

### 5. Conectar à VM

Consulte o IP público do recurso `pip-atlas-dev-app` no portal. O repositório ainda não declara outputs.

```bash
ssh -i ~/.ssh/atlas-dev azureuser@<IP_PUBLICO_DA_VM>
```

Verifique a identidade do servidor no primeiro acesso. Quando solicitada, informe a passphrase da chave privada.

Se o IP público da sua conexão mudar, atualize `ssh_allowed_cidr`, revise o plano e aplique a alteração.

## Validação do laboratório

O provisionamento e o acesso SSH autorizado foram realizados durante o estudo. Isso não comprova o bloqueio de todas as demais origens.

Teste pendente no Windows/PowerShell:

```powershell
Test-NetConnection -ComputerName <IP_PUBLICO_DA_VM> -Port 22
```

Compare duas novas conexões:

| Origem | Resultado esperado |
|---|---|
| Rede cujo IP público está autorizado | `TcpTestSucceeded : True` |
| Outra rede, com IPv4 público diferente | `TcpTestSucceeded : False` |

Um timeout isolado também pode ter outras causas. Compare com a origem autorizada e confira VM, IP de destino e regras efetivas. Não é necessário copiar a chave privada para realizar esse teste TCP.

O acesso ao banco só poderá ser validado após implantar o PostgreSQL e configurar o serviço.

## Custos, estado e encerramento

Este laboratório utiliza recursos cobrados. O custo depende da região, tamanho da VM, disco, IP público, tráfego e tempo de uso. Não há orçamento ou desligamento automático implementado no código.

Desalocar a VM não elimina os custos de discos e do IP público estático. Confira o Cost Management e a calculadora Azure antes de reproduzir o ambiente.

O estado local não deve entrar no Git, mas precisa ser preservado de forma segura. Ignorá-lo no versionamento não equivale a fazer backup.

Para encerrar o laboratório, no diretório com o estado correto:

```bash
terraform plan -destroy
terraform destroy
```

Revise o que será removido e preserve dados necessários antes de confirmar. Após a execução, confira a remoção dos recursos no portal.

## Limitações e próximos passos

- [ ] Concluir o teste de bloqueio SSH por outra origem.
- [ ] Revisar a refatoração por responsabilidade e a nomenclatura `app` / `api`.
- [ ] Planejar a transição para um único ambiente PRD simulado.
- [ ] Adicionar outputs úteis.
- [ ] Implantar PostgreSQL e uma API simples em C#.
- [ ] Implementar métricas, logs e alertas.
- [ ] Implementar backup e testar restauração.
- [ ] Avaliar estado remoto e validações automatizadas.

A transição DEV → PRD não consiste apenas em trocar uma variável: nomes podem provocar substituição de recursos. Renomear identificadores Terraform também requer tratar sua relação com o estado. Mover blocos entre arquivos na mesma pasta, mantendo identificadores e valores, é uma reorganização sem mudança esperada na infraestrutura.

Esta base não inclui alta disponibilidade, backup, observabilidade ou testes automatizados. Essas capacidades fazem parte da evolução do estudo.

## Referências

- [Documentação do Terraform](https://developer.hashicorp.com/terraform/docs)
- [Provider AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [NSGs na Azure](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [ASGs na Azure](https://learn.microsoft.com/azure/virtual-network/application-security-groups)
- [Preços de IPs públicos](https://azure.microsoft.com/pricing/details/ip-addresses/)
