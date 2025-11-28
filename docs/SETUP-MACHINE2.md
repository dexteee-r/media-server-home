# GUIDE INSTALLATION : MACHINE #2 (INTRANET NODE)

## ÉTAPE 1 : Installation Matérielle (30 min)

### 1.1 - Installer Disque 4 TB
```bash
# Éteindre Machine #2
# Ouvrir boîtier
# Installer HDD 4 TB dans baie libre :
#   - Connecter câble SATA data vers carte mère
#   - Connecter câble SATA power depuis alimentation
# Vérifier ventilation GPU GTX 980 (dépoussièrer si besoin)
# Refermer boîtier
```

### 1.2 - Vérification BIOS
```
# Boot sur BIOS (DEL ou F2 au démarrage)
# Vérifier présence disques :
#   ├─ SSD 500 GB SATA (boot primaire)
#   └─ HDD 4 TB SATA (data)
# Activer virtualisation :
#   ├─ Intel VT-x : Enabled
#   ├─ Intel VT-d : Enabled
#   └─ IOMMU : Enabled
# Sauvegarder + Redémarrer
```

---

## ÉTAPE 2 : Installation Proxmox VE 8.4 (1h)

### 2.1 - Boot USB Proxmox
```
# Insérer USB bootable Proxmox VE 8.4
# Boot menu (F12 généralement)
# Sélectionner USB
# Attendre menu Proxmox Installer
```

### 2.2 - Configuration Installation
```
Target Harddisk : /dev/sda (SSD 500 GB)
├─ Filesystem : ext4 (simple, stable)
├─ Taille partition : 500 GB
└─ ATTENTION : Efface Windows complètement !

Pays/Timezone : Belgium / Europe/Brussels
Clavier : French (Belgium) ou US International

Mot de passe root : [CHOISIR MOT DE PASSE FORT]
Email : ton@email.com (pour alertes)

Réseau :
├─ Interface : enp0s31f6 (ou similaire)
├─ Hostname : pve-intranet
├─ IP Address : 192.168.1.101/24
├─ Gateway : 192.168.1.1
└─ DNS : 192.168.1.1 (ou 8.8.8.8)

Confirmer installation → Attendre 10-15 min
```

### 2.3 - Premier Boot
```bash
# Retirer USB
# Redémarrer
# Attendre boot Proxmox (30s)

# Accès Web UI depuis PC local :
https://192.168.1.101:8006

# Login :
User: root
Password: [mot de passe choisi]

✅ Si connexion OK → Proxmox installé
```

---

## ÉTAPE 3 : Configuration Proxmox Host (1h)

### 3.1 - Désactiver Enterprise Repo (gratuit)
```bash
# SSH vers Proxmox
ssh root@192.168.1.101

# Désactiver repo payant
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Ajouter repo no-subscription (gratuit)
cat >> /etc/apt/sources.list << EOF
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# Update
apt update && apt upgrade -y
```

### 3.2 - Créer ZFS Pool sur HDD 4 TB
```bash
# Vérifier détection disque
lsblk
# Sortie attendue :
# sda  500G  (SSD Proxmox)
# sdb  4T    (HDD nouveau)

# Créer ZFS pool
zpool create \
  -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -m /mnt/data-pool \
  data-pool /dev/sdb

# Vérifier création
zpool status data-pool

# Créer datasets pour chaque usage
zfs create data-pool/photos      # Immich
zfs create data-pool/files        # Nextcloud
zfs create data-pool/backups      # Restic
zfs create data-pool/media        # Vidéos (si besoin futur)

# Définir quotas (optionnel mais recommandé)
zfs set quota=1.5T data-pool/photos   # Max 1.5 TB photos
zfs set quota=1.5T data-pool/files    # Max 1.5 TB fichiers
zfs set quota=500G data-pool/backups  # Max 500 GB backups
zfs set quota=500G data-pool/media    # Max 500 GB vidéos

# Vérifier quotas
zfs list -o name,quota,used,avail
```

### 3.3 - Configurer NFS Shares (pour VMs)
```bash
# Installer NFS server
apt install nfs-kernel-server -y

# Ajouter exports NFS
cat >> /etc/exports << EOF
/mnt/data-pool/photos 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/files 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/data-pool/backups 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF

# Appliquer config
exportfs -ra
systemctl restart nfs-server

# Vérifier exports
showmount -e localhost
```

### 3.4 - Ajouter Storage dans Proxmox Web UI
```
# Aller dans Web UI : https://192.168.1.101:8006
# Datacenter > Storage > Add > NFS

ID : nfs-photos
Server : 192.168.1.101
Export : /mnt/data-pool/photos
Content : VZDump backup file, Disk image

Répéter pour :
- nfs-files (export /mnt/data-pool/files)
- nfs-backups (export /mnt/data-pool/backups)
```

---

## ÉTAPE 4 : Créer VM-INTRANET (1h)

### 4.1 - Upload ISO Debian
```
# Web UI : pve-intranet > local (pve-intranet) > ISO Images
# Upload ISO Debian 13 (debian-13-amd64-netinst.iso)
# Attendre fin upload
```

### 4.2 - Créer VM
```
# Web UI : Create VM

General :
├─ Node : pve-intranet
├─ VM ID : 101
├─ Name : VM-INTRANET
└─ Start at boot : Yes

OS :
├─ ISO : debian-13-amd64-netinst.iso
└─ Type : Linux (6.x - 2.6 Kernel)

System :
├─ Graphics : Default
├─ Machine : q35
├─ BIOS : OVMF (UEFI)
└─ Add EFI Disk : Yes

Disks :
├─ Bus/Device : SCSI (VirtIO SCSI)
├─ Storage : local-lvm
├─ Disk size : 100 GB
├─ Cache : Write back
├─ Discard : Yes
└─ SSD emulation : Yes

CPU :
├─ Sockets : 1
├─ Cores : 3
├─ Type : host
└─ Enable NUMA : No

Memory :
├─ Memory : 6144 MB (6 GB)
└─ Ballooning : Yes

Network :
├─ Bridge : vmbr0
├─ Model : VirtIO (paravirtualized)
└─ Firewall : Yes

Confirmer création
```

### 4.3 - Installer Debian 13 sur VM
```bash
# Démarrer VM
# Console : noVNC

# Installation Debian :
Langue : French / English
Pays : Belgium
Clavier : Belgian / US

Hostname : vm-intranet
Domain : local

Root password : [MOT DE PASSE FORT]
User : [TON_USER]
User password : [MOT DE PASSE]

Partitionnement : Guided - use entire disk (simple)
Disk : /dev/sda (100 GB)

Software selection :
[x] SSH server
[x] Standard system utilities
[ ] Desktop environment (décocher)

Installation GRUB : Yes → /dev/sda

Redémarrer
```

### 4.4 - Configuration Post-Install VM
```bash
# Login SSH depuis Proxmox host
ssh root@192.168.1.101  # (IP VM, pas host)

# Update système
apt update && apt upgrade -y

# Installer outils essentiels
apt install -y \
  curl wget git vim nano \
  net-tools htop tmux \
  docker.io docker-compose \
  nfs-common

# Activer Docker
systemctl enable docker
systemctl start docker

# Ajouter user au groupe docker
usermod -aG docker [TON_USER]

# Configurer IP statique (si DHCP)
nano /etc/network/interfaces
# Exemple :
auto ens18
iface ens18 inet static
  address 192.168.1.101
  netmask 255.255.255.0
  gateway 192.168.1.1
  dns-nameservers 192.168.1.1

# Redémarrer réseau
systemctl restart networking

# Monter NFS shares
mkdir -p /mnt/photos /mnt/files /mnt/backups

# Ajouter au fstab
cat >> /etc/fstab << EOF
192.168.1.101:/mnt/data-pool/photos  /mnt/photos  nfs  defaults  0  0
192.168.1.101:/mnt/data-pool/files   /mnt/files   nfs  defaults  0  0
192.168.1.101:/mnt/data-pool/backups /mnt/backups nfs  defaults  0  0
EOF

# Monter maintenant
mount -a

# Vérifier montage
df -h | grep /mnt
```

---

## ÉTAPE 5 : Déployer Services Docker (1h)

### 5.1 - Créer Structure Configs
```bash
mkdir -p /opt/intranet/{immich,nextcloud,postgres,redis,prometheus,grafana}
cd /opt/intranet
```

### 5.2 - Docker Compose Stack
```yaml
# /opt/intranet/docker-compose.yml
version: '3.8'

services:
  immich:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich
    ports:
      - "2283:3001"
    volumes:
      - /mnt/photos:/usr/src/app/upload
      - ./immich/config:/config
    environment:
      - DB_HOSTNAME=postgres
      - DB_DATABASE_NAME=immich
      - DB_USERNAME=immich
      - DB_PASSWORD=${POSTGRES_PASSWORD_IMMICH}
      - REDIS_HOSTNAME=redis
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    ports:
      - "8080:80"
    volumes:
      - /mnt/files:/var/www/html/data
      - ./nextcloud/config:/var/www/html/config
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD_NEXTCLOUD}
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    container_name: postgres
    ports:
      - "5432:5432"
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD_ROOT}
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/config:/etc/prometheus
      - ./prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    restart: unless-stopped
```

### 5.3 - Variables d'Environnement
```bash
# /opt/intranet/.env
POSTGRES_PASSWORD_ROOT=CHANGE_ME_ROOT
POSTGRES_PASSWORD_IMMICH=CHANGE_ME_IMMICH
POSTGRES_PASSWORD_NEXTCLOUD=CHANGE_ME_NEXTCLOUD
GRAFANA_PASSWORD=CHANGE_ME_GRAFANA
```

### 5.4 - Démarrer Stack
```bash
cd /opt/intranet
docker-compose up -d

# Vérifier logs
docker-compose logs -f

# Vérifier status
docker-compose ps
```

---

## ÉTAPE 6 : Créer VMs Laboratoire (1h)

### 6.1 - VM-DEV-LINUX (Ubuntu)
```
# Web UI : Create VM

VM ID : 201
Name : VM-DEV-LINUX
ISO : ubuntu-24.04-live-server-amd64.iso

CPU : 2 cores
RAM : 4 GB
Disk : 50 GB (local-lvm)
Network : vmbr0

Start at boot : No (on-demand)

Installer Ubuntu normalement
```

### 6.2 - VM-DEV-WINDOWS (Windows 10/11)
```
# Web UI : Create VM

VM ID : 202
Name : VM-DEV-WINDOWS
ISO : Win11_23H2_French_x64.iso

CPU : 2 cores
RAM : 4 GB
Disk : 100 GB (local-lvm)
Network : vmbr0

Start at boot : No (on-demand)

Installer Windows normalement
```

---

## ÉTAPE 7 : Validation Finale (30 min)

### 7.1 - Tests Connectivity
```bash
# Depuis VM-INTRANET
ping 192.168.1.1        # Gateway OK
ping 192.168.1.111      # Machine #1 EXTRANET OK
ping 8.8.8.8            # Internet OK

# Test NFS mounts
touch /mnt/photos/test.txt
ls -lh /mnt/photos/test.txt  # Doit exister
```

### 7.2 - Tests Services
```bash
# Immich
curl http://192.168.1.101:2283/api/server-info

# Nextcloud
curl http://192.168.1.101:8080

# Prometheus
curl http://192.168.1.101:9090/metrics

# Grafana
curl http://192.168.1.101:3000
```

### 7.3 - Tests VMs Lab
```bash
# Démarrer VM-DEV-LINUX
qm start 201

# Vérifier console
qm console 201

# Arrêter après test
qm shutdown 201
```

---

## ✅ CHECKLIST FINALE

Machine #2 (INTRANET) opérationnelle si :
- [x] Proxmox accessible https://192.168.1.101:8006
- [x] ZFS pool 4 TB créé et monté
- [x] NFS shares configurés
- [x] VM-INTRANET running avec services Docker
- [x] Immich accessible depuis LAN (http://192.168.1.101:2283)
- [x] Nextcloud accessible depuis LAN (http://192.168.1.101:8080)
- [x] VM-DEV-LINUX créée (peut démarrer on-demand)
- [x] VM-DEV-WINDOWS créée (peut démarrer on-demand)
- [x] Communication avec Machine #1 OK

Si tout ✅ → Machine #2 complète ! 🎉
```bash
