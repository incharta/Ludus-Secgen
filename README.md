# Automatização de Cenários "Cyber Range"

Projeto final da Licenciatura em Engenharia Informática (ESTiG-IPB, 2025/2026) que integra **Ludus** e **SecGen** sobre **Proxmox** para criar cyber ranges com máquinas vulneráveis isoladas para treino em cibersegurança.

## Visão geral

- **Proxmox** — plataforma de virtualização (KVM/QEMU).
- **Ludus** — orquestração de ranges, templates, VLANs, router e acesso via WireGuard.
- **SecGen** — criação de máquinas vulneráveis a partir de cenários.
- **Vagrant (provider Proxmox)** — fork adaptado para permitir ao SecGen comunicar com a API do Proxmox.

## O que foi feito

- Instalação e configuração do Proxmox + Ludus.
- Instalação do SecGen numa VM Ubuntu 20.04 (incompatibilidades no Debian do host).
- Patches ao `vagrant-proxmox` (endpoint, SSL self-signed, headers POST, skip de forwarded ports, ACLs, full clone).
- Script Bash que automatiza a integração: prepara o `Vagrantfile`, injeta parâmetros do Proxmox e corre o SecGen.
- Workflow: template Ludus - SecGen cria VM vulnerável (full clone), conversão em template (manual), deploy de range isolado com router, DHCP e VPN.

## Estrutura

- `config.yml` — config do Ludus.
- `ludus-range-config.yml` — definição do range.
- `Vagrantfile.proxmox.ludus.template` — template do Vagrant para o SecGen.
- `script.sh` — automação da integração.
- `vagrant-proxmox/` — provider modificado (`connection.rb`, `config_clone.rb`, `clone_vm.rb`, `gemspec`).

## Limitações

Alguns cenários do SecGen estão desatualizados e falham.

## Autor

Nuno Bento (a48172) — orientação: Prof. Tiago Pedrosa, Prof. Jorge Loureiro.
