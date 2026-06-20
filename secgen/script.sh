#!/usr/bin/env bash
set -euo pipefail

SECGEN_DIR="$HOME/SecGen"
PROJ_ROOT="$SECGEN_DIR/projects"

# --- Proxmox/Ludus ---
PVE_API="IP:8006/api2/json"
PVE_NODE="pve"
PVE_USER="john-doe@pam"
PVE_PASS="*************"
PVE_POOL="JD"
PVE_TEMPLATE_NAME="debian-12-x64-server-template"

VM_SSH_USER="debian"
VM_SSH_PASS="debian"

cd "$SECGEN_DIR"

# 0) Escolher scenario random
SCENARIO="$(find scenarios/examples -maxdepth 3 -name '*.xml' | shuf -n 1)"
echo "[+] Scenario: $SCENARIO"

# 1) Gerar o project
ruby secgen.rb --scenario "$SCENARIO" build-project

# 2) Detetar o project criado
LATEST_PROJ="$(find "$PROJ_ROOT" -maxdepth 1 -type d -name 'SecGen*' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
echo "[+] Project: $LATEST_PROJ"

VF="$LATEST_PROJ/Vagrantfile"
cp "$VF" "$VF.secgen.orig"

# 3) Remover blocos do provider
awk '
BEGIN{skip=0}
/^[[:space:]]*[A-Za-z0-9_]+\.vm\.provider[[:space:]]+:virtualbox[[:space:]]+do[[:space:]]+\|[A-Za-z0-9_]+\|[[:space:]]*$/ {skip=1; next}
skip==1 && /^[[:space:]]*end[[:space:]]*$/ {skip=0; next}
skip==1 {next}
{print}
' "$VF" > "$VF.tmp" && mv "$VF.tmp" "$VF"

# 4) Injetar template Proxmox
INJECT_FILE="$LATEST_PROJ/.proxmox_inject.vf"
cat > "$INJECT_FILE" <<EOF
  # --- Proxmox/Ludus (injetado) ---
  config.vm.box = "dummy"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.ssh.username = "${VM_SSH_USER}"
  config.ssh.password = "${VM_SSH_PASS}"
  config.ssh.insert_key = true
  config.ssh.verify_host_key = false

  config.vm.provider :proxmox do |proxmox|
    proxmox.endpoint        = "${PVE_API}"
    proxmox.verify_ssl      = false
    proxmox.user_name       = "${PVE_USER}"
    proxmox.password        = "${PVE_PASS}"
    proxmox.pool            = "${PVE_POOL}"
    proxmox.selected_node   = "${PVE_NODE}"

    proxmox.vm_id_range     = 9000..9100
    proxmox.vm_name_prefix  = "secgen-"

    proxmox.vm_type         = :qemu
    proxmox.qemu_template   = "${PVE_TEMPLATE_NAME}"
    proxmox.qemu_os         = :l26
    proxmox.qemu_disk_size  = "200G"
    proxmox.qemu_storage    = "local-zfs"
    proxmox.qemu_bridge     = "vmbr1000"
    proxmox.qemu_nic_model  = "virtio"

    proxmox.disable_adjust_forwarded_port = true
  end

  # Garantir dependencias para rsync/puppet dentro da VM
  config.vm.provision "shell", inline: <<'SHELL'
    set -eux
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y rsync puppet
    puppet --version
SHELL
EOF

LINE="$(grep -n -m1 'Vagrant\.configure' "$VF" | cut -d: -f1 || true)"
if [[ -z "${LINE}" ]]; then
  echo "[!] ERRO: nao foi encontrado 'Vagrant.configure' em $VF"
  exit 1
fi
sed -i "${LINE}r $INJECT_FILE" "$VF"
rm -f "$INJECT_FILE"

# 5) Trocar redes estaticas por DHCP
sed -i -E 's/(\.vm\.network[[:space:]]+:private_network),[[:space:]]+ip:[[:space:]]+"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"/\1, type: "dhcp", auto_config: false/g' "$VF"

echo "[+] Vagrantfile patchado para Proxmox."

# 6) Validar que o provider proxmox existe
echo "[+] Confirmar provider proxmox no Vagrantfile:"
grep -n 'config\.vm\.provider[[:space:]]*:proxmox' "$VF" >/dev/null || { echo "[!] Falhou: no existe provider proxmox no Vagrantfile"; exit 1; }
grep -n 'proxmox\.endpoint'  "$VF" >/dev/null || { echo "[!] Falhou: no existe proxmox.endpoint"; exit 1; }
grep -n 'proxmox\.user_name' "$VF" >/dev/null || { echo "[!] Falhou: no existe proxmox.user_name"; exit 1; }
grep -n 'proxmox\.password'  "$VF" >/dev/null || { echo "[!] Falhou: no existe proxmox.password"; exit 1; }
grep -n 'proxmox\.vm_type'   "$VF" >/dev/null || { echo "[!] Falhou: no existe proxmox.vm_type"; exit 1; }

# 7) Subir VMs
cd "$LATEST_PROJ"
vagrant validate
vagrant up --provider=proxmox

echo "[+] DONE: $LATEST_PROJ"
