# SETUP.md - Installation complète Homelab

## 📑 Table des matières

- **Phase 1** : Installation Proxmox VE
- **Phase 2** : Configuration stockage (ZFS/Btrfs)
- **Phase 3** : Réseau Proxmox (vmbr0)
- **Phase 4** : Sécurité hôte Proxmox
- **Phase 5** : Création VM-EXTRANET (Debian 13)
- **Phase 6** : Configuration VM-EXTRANET (NPM + OpenVPN)
- **Phase 7** : Création VM-INTRANET (Debian 13)
- **Phase 8** : Configuration VM-INTRANET (Docker stack)
- **Phase 9** : DNS dynamique (ddclient + OVH)
- **Phase 10** : Tests et validation

---

## Phase 5 : Création VM-EXTRANET (Debian 13)

### 5.1 - Télécharger ISO Debian 13

```bash
# Depuis interface Proxmox (Shell)
cd /var/lib/vz/template/iso

# Télécharger ISO Debian Testing (Trixie)
wget https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso

# Vérifier checksum
sha512sum debian-testing-amd64-netinst.iso
# Comparer avec https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/SHA512SUMS
```

### 5.2 - Créer VM-EXTRANET

**Interface Proxmox → Create VM** :

```yaml
General:
  Node: pve (votre node Proxmox)
  VM ID: 100
  Name: VM-EXTRANET
  Start at boot: ✅

OS:
  ISO image: debian-testing-amd64-netinst.iso
  Type: Linux
  Version: 6.x - 2.6 Kernel

System:
  Graphic card: Default
  Machine: q35
  BIOS: OVMF (UEFI)
  Add EFI Disk: ✅ (storage: local-lvm, size: 4 MB)
  SCSI Controller: VirtIO SCSI single
  Qemu Agent: ✅ (installer plus tard)

Disks:
  Bus/Device: SCSI 0
  Storage: local-lvm
  Disk size: 32 GB
  Cache: Write back
  Discard: ✅ (TRIM support)
  SSD emulation: ✅

CPU:
  Sockets: 1
  Cores: 2
  Type: host (meilleure performance)

Memory:
  Memory: 4096 MB (4 GB)
  Minimum memory: 2048 MB
  Ballooning: ✅

Network:
  Bridge: vmbr0
  Model: VirtIO (paravirtualized)
  Firewall: ❌ (géré par UFW dans VM)
```

**Confirmer et démarrer VM** :
```bash
# Démarrer VM
qm start 100

# Ouvrir console
# Interface Proxmox → VM 100 → Console
```

### 5.3 - Installer Debian 13

**Installation graphique (recommandé)** :

```yaml
# Écran 1 : Langue
Language: English
Location: Belgium
Keyboard: French (Belgium)

# Écran 2 : Réseau
Hostname: vm-extranet
Domain name: (laisser vide)
Configure network: Manual
  IP address: 192.168.1.100
  Netmask: 255.255.255.0
  Gateway: 192.168.1.1
  Name server: 1.1.1.1

# Écran 3 : Utilisateurs
Root password: [mot de passe fort]
Create user: admin
User password: [mot de passe fort]

# Écran 4 : Partitionnement
Partitioning method: Manual
Select disk: SCSI1 (0,0,0) (sda) - 32.0 GB

Créer partitions:
  - /dev/sda1 : 512 MB, ext4, /boot
  - /dev/sda2 : reste, LVM physical volume
    - VG: vg0
      - lv_root : 20 GB, ext4, /
      - lv_swap : 2 GB, swap
      - lv_home : reste (~10 GB), ext4, /home

# Écran 5 : Gestionnaire de paquets
Debian archive mirror country: Belgium
Debian archive mirror: deb.debian.org
HTTP proxy: (laisser vide)

# Écran 6 : Logiciels
Software selection:
  [X] SSH server
  [X] Standard system utilities
  [ ] Debian desktop environment (décocher)
  [ ] Web server (installer via Docker)

# Écran 7 : GRUB
Install GRUB: Yes
Device: /dev/sda

# Écran 8 : Fin
Installation complete
Continue → Reboot
```

### 5.4 - Post-installation VM-EXTRANET

**Se connecter en SSH** :
```bash
# Depuis PC local
ssh admin@192.168.1.100
```

**Mise à jour système** :
```bash
# Passer root
su -

# Mise à jour
apt update && apt upgrade -y

# Installer paquets essentiels
apt install -y \
  curl wget vim git \
  ufw fail2ban \
  htop ncdu iotop \
  net-tools dnsutils \
  qemu-guest-agent \
  sudo

# Ajouter admin au groupe sudo
usermod -aG sudo admin

# Activer qemu-agent
systemctl enable --now qemu-guest-agent

# Reboot
reboot
```

**Vérifier réseau** :
```bash
ip addr show
# Doit afficher 192.168.1.100

ping -c 4 1.1.1.1
# Doit fonctionner

ping -c 4 google.com
# Doit fonctionner (DNS OK)
```

---

## Phase 6 : Configuration VM-EXTRANET (NPM + OpenVPN)

### 6.1 - Configuration firewall UFW

```bash
# SSH depuis admin@192.168.1.100

# Règles par défaut
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH depuis LAN uniquement
sudo ufw allow from 192.168.1.0/24 to any port 22 comment 'SSH from LAN'

# HTTP/HTTPS depuis Internet (NPM)
sudo ufw allow 80/tcp comment 'HTTP (NPM)'
sudo ufw allow 443/tcp comment 'HTTPS (NPM)'

# OpenVPN depuis Internet
sudo ufw allow 1194/udp comment 'OpenVPN'

# Activer firewall
sudo ufw enable

# Vérifier status
sudo ufw status verbose
```

### 6.2 - Configuration Fail2ban

```bash
# Installer fail2ban (déjà fait Phase 5.4)

# Configuration SSH
sudo tee /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

# Démarrer fail2ban
sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

# Vérifier status
sudo fail2ban-client status
```

### 6.3 - Installer Docker

```bash
# Installer Docker depuis dépôts Debian
sudo apt install -y docker.io docker-compose-v2

# Démarrer Docker
sudo systemctl enable --now docker

# Ajouter admin au groupe docker
sudo usermod -aG docker admin

# Se déconnecter/reconnecter pour appliquer groupe
exit
ssh admin@192.168.1.100

# Vérifier installation
docker --version
# Docker version 27.3.1, build ...

docker compose version
# Docker Compose version v2.29.7
```

### 6.4 - Déployer Nginx Proxy Manager

```bash
# Créer dossier NPM
mkdir -p ~/npm
cd ~/npm

# Créer docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
      - 81:81  # Admin UI
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    environment:
      DB_SQLITE_FILE: /data/database.sqlite
    networks:
      - npm-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:81/api"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  npm-net:
    driver: bridge
EOF

# Démarrer NPM
docker compose up -d

# Vérifier logs
docker compose logs -f npm

# Attendre message "Proxy Manager is running"
# Ctrl+C pour quitter logs
```

**Accès interface NPM** :
- URL : http://192.168.1.100:81
- Email : admin@example.com
- Password : changeme

**Premier login** :
1. Changer email → admin@elmzn.be
2. Changer mot de passe → [mot de passe fort]
3. Changer nom → Admin Homelab

### 6.5 - Installer OpenVPN Access Server

```bash
# Télécharger script OpenVPN
cd ~
wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repo-public.asc

# Ajouter dépôt OpenVPN
echo "deb [arch=amd64] http://as-repository.openvpn.net/as/debian bookworm main" | \
  sudo tee /etc/apt/sources.list.d/openvpn-as.list

# Installer OpenVPN AS
sudo apt update
sudo apt install -y openvpn-as

# Configuration initiale (noter mot de passe admin)
sudo ovpn-init --force

# Output example:
# Admin  UI: https://192.168.1.100:943/admin
# Client UI: https://192.168.1.100:943/
# Username: openvpn
# Password: [généré aléatoirement]
```

**Accès interface OpenVPN** :
- URL : https://192.168.1.100:943/admin
- Username : openvpn
- Password : [affiché lors ovpn-init]

**Configuration OpenVPN** :
1. Network Settings :
   - Hostname : vpn.elmzn.be
   - Protocol : UDP
   - Port : 1194
2. VPN Settings :
   - Routing : Yes, using NAT
   - Dynamic IP Address Network : 10.8.0.0/24
3. Save Settings

---

## Phase 7 : Création VM-INTRANET (Debian 13)

### 7.1 - Créer VM-INTRANET

**Interface Proxmox → Create VM** :

```yaml
General:
  VM ID: 101
  Name: VM-INTRANET
  Start at boot: ✅

OS:
  ISO image: debian-testing-amd64-netinst.iso

System:
  [Identique VM-EXTRANET]

Disks:
  Bus/Device: SCSI 0
  Storage: local-lvm
  Disk size: 64 GB (plus grande pour médias)
  Cache: Write back
  Discard: ✅
  SSD emulation: ✅

CPU:
  Sockets: 1
  Cores: 3 (1 de plus que EXTRANET)
  Type: host

Memory:
  Memory: 12288 MB (12 GB)
  Minimum memory: 8192 MB
  Ballooning: ✅

Network:
  Bridge: vmbr0
  Model: VirtIO
  Firewall: ❌
```

### 7.2 - Installer Debian 13

**Installation identique VM-EXTRANET** (voir Phase 5.3), sauf :

```yaml
Hostname: vm-intranet
IP address: 192.168.1.101

Partitionnement:
  - /dev/sda1 : 512 MB, ext4, /boot
  - /dev/sda2 : reste, LVM
    - VG: vg0
      - lv_root : 30 GB, ext4, /
      - lv_swap : 4 GB, swap
      - lv_home : reste (~30 GB), ext4, /home
```

### 7.3 - Post-installation VM-INTRANET

```bash
# SSH depuis PC local
ssh admin@192.168.1.101

# Passer root
su -

# Mise à jour + paquets
apt update && apt upgrade -y
apt install -y \
  curl wget vim git \
  ufw fail2ban \
  htop ncdu iotop \
  net-tools dnsutils \
  qemu-guest-agent \
  sudo

# Ajouter admin au groupe sudo
usermod -aG sudo admin

# Installer Docker
apt install -y docker.io docker-compose-v2
systemctl enable --now docker
usermod -aG docker admin

# Activer qemu-agent
systemctl enable --now qemu-guest-agent

# Reboot
reboot
```

---

## Phase 8 : Configuration VM-INTRANET (Docker stack)

### 8.1 - Configuration firewall UFW

```bash
# SSH depuis admin@192.168.1.101

# Règles par défaut
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH depuis LAN uniquement
sudo ufw allow from 192.168.1.0/24 to any port 22 comment 'SSH from LAN'

# Services accessibles depuis LAN + VPN
sudo ufw allow from 192.168.1.0/24 to any port 8096 comment 'Jellyfin from LAN'
sudo ufw allow from 10.8.0.0/24 to any port 8096 comment 'Jellyfin from VPN'

sudo ufw allow from 192.168.1.0/24 to any port 2283 comment 'Immich from LAN'
sudo ufw allow from 10.8.0.0/24 to any port 2283 comment 'Immich from VPN'

sudo ufw allow from 192.168.1.0/24 to any port 3000 comment 'Grafana from LAN'
sudo ufw allow from 10.8.0.0/24 to any port 3000 comment 'Grafana from VPN'

sudo ufw allow from 192.168.1.0/24 to any port 9090 comment 'Prometheus from LAN'
sudo ufw allow from 10.8.0.0/24 to any port 9090 comment 'Prometheus from VPN'

# Activer firewall
sudo ufw enable

# Vérifier status
sudo ufw status verbose
```

### 8.2 - Créer dossiers pour services

```bash
# Créer structure
mkdir -p ~/homelab/{jellyfin,immich,monitoring}
cd ~/homelab
```

### 8.3 - Déployer Jellyfin

```bash
cd ~/homelab/jellyfin

# Créer docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Brussels
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /media/library:/media:ro  # Montage bind (à créer Phase 8.7)
    ports:
      - 8096:8096
    networks:
      - homelab-net
    devices:
      - /dev/dri:/dev/dri  # Intel QuickSync (transcodage HW)

networks:
  homelab-net:
    driver: bridge
EOF

# Créer dossiers locaux
mkdir -p config cache

# Démarrer Jellyfin
docker compose up -d

# Vérifier logs
docker compose logs -f jellyfin
```

**Accès Jellyfin** :
- URL : http://192.168.1.101:8096
- Setup wizard : créer compte admin

### 8.4 - Déployer Immich

```bash
cd ~/homelab/immich

# Télécharger docker-compose officiel Immich
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml

# Télécharger .env example
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env

# Éditer .env
nano .env
# Modifier :
# DB_PASSWORD=[mot de passe fort PostgreSQL]
# UPLOAD_LOCATION=./library

# Démarrer Immich stack
docker compose up -d

# Vérifier services (Immich + Postgres + Redis)
docker compose ps

# Attendre 30-60s (init DB)
docker compose logs -f immich-server
```

**Accès Immich** :
- URL : http://192.168.1.101:2283
- Setup wizard : créer compte admin

### 8.5 - Déployer Prometheus + Grafana

```bash
cd ~/homelab/monitoring

# Créer docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    ports:
      - 9090:9090
    networks:
      - monitoring-net

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin  # Changer après 1er login
      - GF_INSTALL_PLUGINS=
    volumes:
      - grafana-data:/var/lib/grafana
    ports:
      - 3000:3000
    networks:
      - monitoring-net
    depends_on:
      - prometheus

networks:
  monitoring-net:
    driver: bridge

volumes:
  prometheus-data:
  grafana-data:
EOF

# Créer config Prometheus
cat > prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['192.168.1.101:9100']  # À installer Phase 8.6
EOF

# Démarrer stack
docker compose up -d

# Vérifier logs
docker compose logs -f
```

**Accès Grafana** :
- URL : http://192.168.1.101:3000
- Username : admin
- Password : admin (changer après login)

### 8.6 - Installer Node Exporter (métriques système)

```bash
# Télécharger Node Exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

# Extraire
tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/

# Créer service systemd
sudo tee /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Démarrer service
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Vérifier
curl http://localhost:9100/metrics
```

### 8.7 - Montage stockage médias (bind mount)

```bash
# Créer point de montage
sudo mkdir -p /media/library

# Option A : Montage NFS depuis NAS (si disponible)
sudo apt install -y nfs-common
echo "192.168.1.10:/volume1/media /media/library nfs defaults,_netdev 0 0" | \
  sudo tee -a /etc/fstab
sudo mount -a

# Option B : Montage disque local (si HDD interne)
# Identifier disque (ex: /dev/sdb1)
lsblk
sudo mkfs.ext4 /dev/sdb1
echo "/dev/sdb1 /media/library ext4 defaults 0 2" | \
  sudo tee -a /etc/fstab
sudo mount -a

# Vérifier montage
df -h | grep /media/library

# Permissions
sudo chown -R admin:admin /media/library
sudo chmod -R 755 /media/library
```

---

## Phase 9 : DNS dynamique (ddclient + OVH)

### 9.1 - Configurer DynHost OVH

**Espace client OVH** → Domaines → elmzn.be → DynHost :

1. Créer identifiant DynHost :
   - Suffixe : vpn
   - Sous-domaine : vpn.elmzn.be
   - IP : [laisser vide, MAJ par ddclient]

2. Noter credentials :
   - Login : elmzn.be-vpn
   - Password : [généré par OVH]

### 9.2 - Installer ddclient (VM-EXTRANET)

```bash
# SSH admin@192.168.1.100

# Installer ddclient
sudo apt install -y ddclient

# Ignorer setup wizard (config manuelle après)

# Créer config
sudo tee /etc/ddclient.conf <<'EOF'
daemon=300
syslog=yes
pid=/var/run/ddclient.pid

use=web, web=checkip.dyndns.org/, web-skip='IP Address'

protocol=dyndns2
server=www.ovh.com
login=elmzn.be-vpn
password='VOTRE_MOT_DE_PASSE_DYNHOST'
vpn.elmzn.be
EOF

# Sécuriser fichier
sudo chmod 600 /etc/ddclient.conf

# Redémarrer service
sudo systemctl restart ddclient
sudo systemctl enable ddclient

# Vérifier logs
sudo tail -f /var/log/syslog | grep ddclient

# Test manuel MAJ
sudo ddclient -daemon=0 -debug -verbose -noquiet
```

### 9.3 - Vérifier DNS public

```bash
# Depuis PC local
dig vpn.elmzn.be +short
# Doit afficher IP publique

# Test connexion OpenVPN
# https://vpn.elmzn.be:943
# Doit afficher interface OpenVPN
```

---

## Phase 10 : Tests et validation

### 10.1 - Tester accès services

**Depuis PC LAN (192.168.1.x)** :

```bash
# Jellyfin
curl -I http://192.168.1.101:8096
# HTTP/1.1 200 OK

# Immich
curl -I http://192.168.1.101:2283
# HTTP/1.1 200 OK

# Grafana
curl -I http://192.168.1.101:3000
# HTTP/1.1 200 OK

# Prometheus
curl -I http://192.168.1.101:9090
# HTTP/1.1 200 OK
```

### 10.2 - Configurer proxy NPM

**Interface NPM (http://192.168.1.100:81)** → Proxy Hosts → Add :

**1. Jellyfin (media.elmzn.be)** :
```yaml
Domain Names: media.elmzn.be
Scheme: http
Forward Hostname/IP: 192.168.1.101
Forward Port: 8096
Block Common Exploits: ✅
Websockets Support: ✅
SSL: Request SSL Certificate (Let's Encrypt)
  Email: admin@elmzn.be
  Agree to ToS: ✅
  Force SSL: ✅
```

**2. Immich (photos.elmzn.be)** :
```yaml
Domain Names: photos.elmzn.be
Forward Hostname/IP: 192.168.1.101
Forward Port: 2283
[Même config SSL que Jellyfin]
```

**3. Grafana (grafana.elmzn.be)** :
```yaml
Domain Names: grafana.elmzn.be
Forward Hostname/IP: 192.168.1.101
Forward Port: 3000
Access List: LAN_VPN (créer liste : 192.168.1.0/24, 10.8.0.0/24)
[Même config SSL]
```

### 10.3 - Tester accès externe (via domaine)

**Depuis PC LAN** :

```bash
# Ajouter entries /etc/hosts (Split DNS temporaire)
echo "192.168.1.100 media.elmzn.be photos.elmzn.be grafana.elmzn.be" | \
  sudo tee -a /etc/hosts

# Tester HTTPS
curl -I https://media.elmzn.be
# HTTP/2 200
# strict-transport-security: max-age=31536000

curl -I https://photos.elmzn.be
# HTTP/2 200

curl -I https://grafana.elmzn.be
# HTTP/2 200
```

**Depuis mobile 4G (hors LAN)** :
1. Ouvrir navigateur
2. https://vpn.elmzn.be:943
3. Login OpenVPN → télécharger profil client
4. Connecter VPN
5. Tester https://media.elmzn.be → doit fonctionner

### 10.4 - Tests de performance

```bash
# Test transcodage Jellyfin
# Depuis interface Jellyfin :
# Dashboard → Playback → Start playback
# Vérifier CPU usage (doit rester <50% avec QuickSync)

# Test upload Immich
# Depuis app mobile Immich :
# Paramètres → URL : https://photos.elmzn.be
# Upload 10 photos → vérifier temps <30s

# Test métriques Prometheus
curl http://192.168.1.101:9090/api/v1/query?query=up
# {"status":"success","data":...}
```

### 10.5 - Tests de sécurité

```bash
# Test firewall UFW
nmap -p 22,80,443,1194,8096 192.168.1.100
# Ports 80,443,1194 : open
# Port 22 : filtered (si scan depuis WAN)
# Port 8096 : closed

# Test fail2ban
# Tenter 5 connexions SSH avec mauvais mdp :
ssh wronguser@192.168.1.100
# Après 3 échecs → IP banned 1h

# Vérifier ban
sudo fail2ban-client status sshd
# IP addresses banned: 1
```

### 10.6 - Validation checklist

**Infrastructure** :
- [x] Proxmox VE installé et accessible
- [x] VM-EXTRANET (192.168.1.100) opérationnelle
- [x] VM-INTRANET (192.168.1.101) opérationnelle
- [x] Réseau vmbr0 configuré
- [x] Stockage /media/library monté

**Services VM-EXTRANET** :
- [x] NPM opérationnel (port 81)
- [x] OpenVPN accessible (vpn.elmzn.be:943)
- [x] ddclient met à jour DNS OVH
- [x] UFW + fail2ban actifs

**Services VM-INTRANET** :
- [x] Jellyfin accessible (8096)
- [x] Immich accessible (2283)
- [x] Prometheus accessible (9090)
- [x] Grafana accessible (3000)
- [x] Node Exporter actif (9100)

**DNS & SSL** :
- [x] vpn.elmzn.be résolu (IP publique)
- [x] media.elmzn.be → Jellyfin (HTTPS ✅)
- [x] photos.elmzn.be → Immich (HTTPS ✅)
- [x] grafana.elmzn.be → Grafana (HTTPS ✅)

**Sécurité** :
- [x] SSH accessible uniquement depuis LAN
- [x] Services sensibles protégés par Access Lists
- [x] fail2ban actif sur SSH
- [x] Certificats SSL valides (Let's Encrypt)

---

## 🎉 Installation terminée !

**Prochaines étapes** :
1. Ajouter contenu médias dans `/media/library`
2. Configurer bibliothèques Jellyfin
3. Créer profils OpenVPN clients
4. Importer dashboards Grafana
5. Configurer backups automatiques

**Accès rapide** :
- NPM : http://192.168.1.100:81
- OpenVPN : https://vpn.elmzn.be:943
- Jellyfin : https://media.elmzn.be
- Immich : https://photos.elmzn.be
- Grafana : https://grafana.elmzn.be (LAN/VPN only)

**Support** :
- Documentation ADR : `docs/ADR/`
- Cheatsheet : `CHEATSHEET.md`
- Journal de bord : `docs/JOURNAL.md`