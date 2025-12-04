# 🏠 Media Server Home - Infrastructure Homelab

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_9.1-orange)](https://www.proxmox.com/)
[![Debian](https://img.shields.io/badge/Debian-13_Trixie-red)](https://www.debian.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)

> **Infrastructure de production 24/7** pour auto-hébergement de services familiaux et laboratoire d'apprentissage système/réseau.

---

## 📊 Vue d'Ensemble

**Type :** Homelab 2 machines (EXTRANET/INTRANET séparés)  
**Objectif :** Stockage photos/fichiers famille + VMs laboratoire + apprentissage DevOps  
**Stack :** Proxmox VE + Debian + Docker Compose + ZFS  
**Sécurité :** Architecture DMZ multi-couches

### 🎯 Cas d'Usage Principaux

- ✅ **Stockage photos famille** (Immich) - 2 TB disponible
- ✅ **Partage fichiers** (Nextcloud - futur) - accès web + mobile
- ✅ **VMs laboratoire** (Debian test) - apprentissage
- ✅ **Monitoring** (Prometheus + Grafana)
- ✅ **Accès distant sécurisé** (OpenVPN - M1)
- ✅ **Reverse proxy SSL** (Nginx Proxy Manager)

---

## 🗺️ Architecture

### **Vue d'Ensemble**
```
Internet (WAN)
    ↓
Box Internet (192.168.1.1)
├─ Port forwarding :
│  ├─ 80/443 → Machine #1 (prévu)
│  └─ 1194/udp → Machine #1 (OpenVPN)
│
└─ LAN (192.168.1.0/24)
   │
   ├─ Machine #1 : EXTRANET (DMZ)
   │  ├─ IP : 192.168.1.111
   │  ├─ Rôle : Exposition Internet UNIQUEMENT
   │  ├─ Hardware : Dell OptiPlex 7040 (i5-6500, 16GB RAM)
   │  └─ Services : NPM public, OpenVPN, Fail2ban
   │
   └─ Machine #2 : INTRANET (Privé)
      ├─ IP Host : 192.168.1.200
      ├─ IP VM : 192.168.1.201
      ├─ Rôle : Stockage + Services + VMs Lab
      ├─ Hardware : Custom PC (i7-6700, 16GB RAM, GTX 980, 4TB HDD)
      └─ Services : Immich, NPM local, Grafana, Prometheus, VMs dev
```

**Principe :** Machine #2 **JAMAIS** exposée directement à Internet.

---

## 🖥️ Matériel

### **Machine #1 : EXTRANET (Dell OptiPlex 7040)**

| Composant | Specs |
|-----------|-------|
| **CPU** | Intel Core i5-6500 (4C/4T @ 3.2-3.6 GHz) |
| **RAM** | 16 GB DDR4-2133 |
| **SSD** | Samsung NVMe 256 GB (Proxmox + VMs) |
| **HDD** | 500 GB SATA (backups Machine #2) |
| **GPU** | Intel HD 530 (iGPU) |
| **Réseau** | Gigabit Ethernet |

### **Machine #2 : INTRANET (Custom Build)**

| Composant | Specs |
|-----------|-------|
| **CPU** | Intel Core i7-6700 (4C/**8T** @ 3.4-4.0 GHz) |
| **RAM** | 16 GB DDR4-2133 |
| **SSD** | Crucial MX500 447 GB (Proxmox + VMs) |
| **HDD** | Seagate IronWolf 4 TB NAS (stockage ZFS) |
| **GPU** | NVIDIA GeForce GTX 980 (4 GB GDDR5) |
| **Réseau** | Gigabit Ethernet |
| **Alim** | 850W |

---

## 🐳 Services Déployés

### **Machine #2 : INTRANET (Production)**

| Service | URL | Description |
|---------|-----|-------------|
| **Immich** | https://immich.intranet.elmzn.be | Gestion photos famille (2 TB) |
| **Nginx Proxy Manager** | https://npm.intranet.elmzn.be | Reverse proxy local + SSL |
| **Grafana** | https://grafana.intranet.elmzn.be | Dashboards monitoring |
| **Prometheus** | https://prometheus.intranet.elmzn.be | Collecte métriques |
| **PostgreSQL** | 192.168.1.201:5432 | Base de données Immich |
| **Redis** | 192.168.1.201:6379 | Cache Immich |
| **Node Exporter** | 192.168.1.201:9100 | Métriques système |

### **Stockage ZFS (4TB HDD)**

| Dataset | Quota | Usage | Mountpoint |
|---------|-------|-------|------------|
| `data-pool/photos` | 2 TB | Immich uploads | `/mnt/data-pool/photos` |
| `data-pool/files` | 512 GB | Nextcloud (futur) | `/mnt/data-pool/files` |
| `data-pool/backups` | 512 GB | Snapshots + Restic | `/mnt/data-pool/backups` |
| `data-pool/media` | 512 GB | Vidéos (futur) | `/mnt/data-pool/media` |

**Partage réseau:**
- **NFS:** Accessible depuis VMs Proxmox (192.168.1.0/24)
- **Samba:** Accessible depuis Windows/Mac (`\\192.168.1.200`)

---

## 🚀 Quick Start

### **Prérequis**

- Proxmox VE 9.1 installé sur Machine #2
- Docker + Docker Compose installés
- Domaine public avec DNS dynamique (ex: `elmzn.be` via OVH)
- Accès SSH aux machines

### **Installation Machine #2 (INTRANET)**

#### **1. Préparer l'environnement**
```bash
# SSH vers VM-INTRANET
ssh admin@192.168.1.201

# Créer structure
sudo mkdir -p /srv/intranet
cd /srv/intranet
```

#### **2. Télécharger configuration**
```bash
# Cloner le repo
git clone https://github.com/TON_USER/media-server-home.git
cd media-server-home

# Copier docker-compose.yml
cp configs/machine2-intranet/docker-compose.yml /srv/intranet/
cp configs/machine2-intranet/.env.example /srv/intranet/.env
```

#### **3. Configurer variables d'environnement**
```bash
# Éditer .env
nano /srv/intranet/.env

# Générer passwords forts
openssl rand -base64 32  # Pour DB_PASSWORD
openssl rand -base64 32  # Pour GRAFANA_PASSWORD
```

**Contenu `.env` minimal:**
```bash
DB_PASSWORD=ton_password_postgres_32_chars
GRAFANA_PASSWORD=ton_password_grafana_32_chars
```

#### **4. Monter NFS depuis Proxmox host**
```bash
# Créer points de montage
sudo mkdir -p /mnt/{photos,files,backups,media}

# Ajouter à /etc/fstab
sudo nano /etc/fstab

# Ajouter ces lignes:
192.168.1.200:/mnt/data-pool/photos  /mnt/photos  nfs defaults 0 0
192.168.1.200:/mnt/data-pool/files   /mnt/files   nfs defaults 0 0
192.168.1.200:/mnt/data-pool/backups /mnt/backups nfs defaults 0 0
192.168.1.200:/mnt/data-pool/media   /mnt/media   nfs defaults 0 0

# Monter tous
sudo mount -a

# Vérifier
df -h | grep nfs
```

#### **5. Lancer la stack Docker**
```bash
cd /srv/intranet
docker compose up -d

# Attendre 30 secondes
sleep 30

# Vérifier statut
docker compose ps
```

**Tous les containers doivent être `Up` et `healthy`.**

#### **6. Accéder aux services**

**Première connexion NPM:**
```
URL: http://192.168.1.201:81
Email: admin@example.com
Password: changeme

⚠️ CHANGER IMMÉDIATEMENT email + password
```

**Configurer certificat SSL:**
1. NPM → **SSL Certificates**
2. **Add SSL Certificate** → **Let's Encrypt**
3. **Domain Names:** `*.intranet.elmzn.be`
4. **Use DNS Challenge:** ✅ OVH
5. **Credentials:** (API keys OVH)
6. **Save**

**Créer Proxy Hosts:**
1. NPM → **Hosts** → **Add Proxy Host**
2. **Domain:** `immich.intranet.elmzn.be`
3. **Forward Hostname:** `immich_server`
4. **Forward Port:** `2283`
5. **SSL Certificate:** `*.intranet.elmzn.be`
6. **Force SSL:** ✅
7. **Websockets Support:** ✅ (CRITIQUE)
8. **Save**

Répéter pour:
- `npm.intranet.elmzn.be` → `npm:81`
- `grafana.intranet.elmzn.be` → `grafana:3000`
- `prometheus.intranet.elmzn.be` → `prometheus:9090`

#### **7. Configurer Immich**
```
URL: https://immich.intranet.elmzn.be
```

1. **Getting Started** → Créer compte admin
2. **Username:** ton_username
3. **Password:** (fort + noter dans gestionnaire mots de passe)
4. **Confirm Password**
5. **Sign Up**

**Upload photos:**
1. **Upload** (bouton `+`)
2. Sélectionner photos
3. Photos stockées dans `/mnt/photos` (ZFS)

---

## 📖 Documentation Complète

### **Guides d'Installation**

- 🚀 [**SETUP-MACHINE1.md**](docs/SETUP-MACHINE1.md) - Configuration EXTRANET (à venir)
- 🚀 [**SETUP-MACHINE2.md**](docs/SETUP-MACHINE2.md) - Configuration INTRANET détaillée
- 🚀 [**INSTALL-M2-COMPLETE.md**](docs/INSTALL-M2-COMPLETE.md) - Setup complet M2

### **Documentation Technique**

- 📁 [**ARCHITECTURE.md**](docs/ARCHITECTURE.md) - Architecture détaillée
- 🔒 [**SECURITY.md**](docs/SECURITY.md) - Politique sécurité
- 📊 [**OPERATIONS.md**](docs/OPERATIONS.md) - Runbooks maintenance
- 📝 [**ADR/**](docs/ADR/) - Architecture Decision Records

### **Journal de Bord**

- 📓 [**Setup Homelab Machine #2**](docs/JOURNAL%20DE%20BORD/Setup-Homelab-Machine-#2.md) - Historique setup détaillé (02-04 déc 2025)

---

## 🔧 Opérations Courantes

### **Gestion Services Docker**
```bash
# Démarrer stack
cd /srv/intranet
docker compose up -d

# Arrêter stack
docker compose down

# Voir logs
docker compose logs -f immich_server
docker compose logs -f grafana

# Redémarrer service
docker compose restart immich_server

# Voir statut
docker compose ps
```

### **Gestion VMs Proxmox**
```bash
# SSH vers Proxmox M2
ssh root@192.168.1.200

# Lister VMs
qm list

# Démarrer VM
qm start 101   # VM-INTRANET
qm start 102   # VM-DEBIAN-TEST

# Arrêter VM
qm stop 101

# Voir statut
qm status 101
```

### **Gestion ZFS**
```bash
# Statut pool
zpool status data-pool

# Liste datasets
zfs list

# Quotas
zfs get quota data-pool/photos

# Créer snapshot manuel
zfs snapshot data-pool/photos@backup-$(date +%Y%m%d)

# Lister snapshots
zfs list -t snapshot
```

### **Backups**
```bash
# Backup manuel M2 → M1
./scripts/backup-m2-to-m1.sh

# Restaurer (exemple)
restic restore latest --target /restore --tag photos
```

---

## 🔒 Sécurité

### **Architecture Defense in Depth**

1. **Box Firewall** - Ports 80/443/1194 UNIQUEMENT vers Machine #1
2. **Proxmox Firewall** - Règles datacenter + VM + node
3. **UFW Machine #2** - Allow depuis M1 + LAN ONLY, deny Internet direct
4. **NPM Access Lists** - Grafana/Prometheus = LAN + VPN uniquement
5. **Fail2ban** - Auto-ban bruteforce (M1)
6. **Application Auth** - Comptes + passwords forts

**Principe:** Machine #2 JAMAIS exposée directement Internet.

---

## 💾 Backups

### **Stratégie**

- **Quotidien:** Configs Docker, DB PostgreSQL
- **Hebdomadaire:** Photos Immich (incrémental)
- **Mensuel:** Fichiers complets
- **Rétention:** 7 daily, 4 weekly, 6 monthly

### **Destinations**

- **Local:** Machine #1 (500 GB HDD)
- **Offsite:** À implémenter (Backblaze B2)

---

## 📊 Monitoring

**Accès Grafana:** `https://grafana.intranet.elmzn.be`

**Dashboards:**
- Node Exporter Full (CPU, RAM, Disk, Network)
- Docker Monitoring (Containers)
- Custom (Services uptime)

---

## 📋 État du Projet

### ✅ Complété

- [x] Proxmox M2 installé (VE 9.1)
- [x] ZFS pool 4TB configuré avec quotas
- [x] NFS + Samba opérationnels
- [x] VM-INTRANET Debian 13 déployée
- [x] Stack Docker complète (Immich, NPM, Grafana, Prometheus)
- [x] Certificats SSL Let's Encrypt
- [x] Proxy hosts NPM configurés
- [x] Immich fonctionnel avec uploads
- [x] VM Debian test créée

### 🔄 En Cours

- [ ] Configuration NPM M1 (reverse proxy public)
- [ ] Port forwarding box Internet
- [ ] Tests accès externe
- [ ] Backups automatisés

### 📅 Prochaines Étapes

- [ ] Nextcloud déploiement
- [ ] Vaultwarden (gestionnaire mots de passe)
- [ ] Uptime Kuma (monitoring uptime)
- [ ] Pi-hole / AdGuard Home (DNS ad-blocker)

---

## 🤝 Contribution

Projet **éducatif** et **personnel**. Suggestions bienvenues via Issues !

---

## 📞 Ressources

### **Documentation Officielle**

- [Proxmox VE](https://pve.proxmox.com/wiki/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Immich](https://immich.app/docs/)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [ZFS Documentation](https://openzfs.github.io/openzfs-docs/)

### **Communauté**

- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/Proxmox](https://reddit.com/r/Proxmox)
- [r/homelab](https://reddit.com/r/homelab)

---

## 📜 License

Projet sous licence **MIT** - voir [LICENSE](LICENSE).

---

## 🙏 Remerciements

- Communauté r/selfhosted pour inspiration
- Projet Immich pour excellent logiciel photos
- Proxmox team pour hyperviseur open-source

---

**Dernière mise à jour:** 04 décembre 2025  
**Version architecture:** 2.0 (2 machines EXTRANET/INTRANET)

---

<div align="center">
  <b>Made with ❤️ for learning and family</b>
</div>
```

---

## 2️⃣ LICENSE (MIT)

Crée fichier `LICENSE` à la racine:
```
MIT License

Copyright (c) 2025 [Ton Nom ou Username GitHub]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.