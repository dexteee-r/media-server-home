# 🏠 CONTEXTE PROJET : Media Server Home

## 📊 Vue d'ensemble

**Type :** Homelab multi-VM auto-hébergé (production 24/7)  
**Objectif :** Serveur multimédia avec streaming (Jellyfin), gestion photos (Immich), monitoring et backups automatiques  
**Niveau :** Production personnelle + portfolio professionnel  
**Stack :** Proxmox VE 8.4 + Debian 13 + Docker Compose + ZFS

---

## 🖥️ Infrastructure matérielle

**Machine physique : Dell OptiPlex 7040**
```
OS hôte : Proxmox VE 8.4 (bare-metal, Debian-based)
          └─ Installation : SSD NVMe (Windows 11 effacé complètement)

CPU : Intel Core i5-6500 (Skylake, 4C/4T @ 3.2-3.6 GHz)
      ├─ VT-x, VT-d activés (virtualisation)
      └─ QuickSync (transcodage H.264/H.265)

RAM : 16 GB DDR4-2133 (single channel)
      └─ Allocation : 4 GB EXTRANET + 12 GB INTRANET

Stockage :
├─ SSD NVMe 256 GB (Samsung MZVLW256, santé 98%)
│  ├─ Proxmox VE 8.4 : 20 GB (installation bare-metal)
│  ├─ VMs OS : 60 GB (20 GB EXTRANET + 40 GB INTRANET)
│  └─ ZFS tank-ssd : 150 GB
│     ├─ appdata : 30 GB (configs Docker)
│     └─ postgres : 20 GB (DB Immich)
│
└─ HDD 500 GB (SATA, nouveau, upgrade 2 To prévu 6-12 mois)
   └─ ZFS tank-hdd : 450 GB
      ├─ media : 250 GB (vidéos Jellyfin)
      ├─ photos : 100 GB (uploads Immich)
      ├─ backups : 50 GB (Restic repo)
      └─ logs : 10 GB

GPU : Intel HD 530 (passthrough vers VM-INTRANET)
      └─ Transcodage hardware Jellyfin (VAAPI)

Réseau : Intel I219-LM Gigabit Ethernet (1 interface physique)
```

**⚠️ Note importante :** Windows 11 a été **complètement effacé** lors de l'installation Proxmox VE. Le SSD a été reformaté et partitionné pour Proxmox + ZFS. Pas de dual-boot.

---

## 🏗️ Architecture logicielle (FINALE - 03/11/2025)

### **Stack complète**
```
Proxmox VE 8.4 (bare-metal hypervisor, base Debian 12)
├─ Interface physique : enp0s31f6 (1 Gbps)
├─ Bridge unique : vmbr0 (192.168.1.0/24)
├─ IP hôte Proxmox : 192.168.1.100 (web UI :8006)
│
├─ VM-EXTRANET (ID 100) - DMZ
│  ├─ OS : Debian 13 (Trixie) - Installation minimale
│  ├─ IP : 192.168.1.111
│  ├─ RAM : 4 GB | vCPU : 2 | Disque : 20 GB (SSD)
│  ├─ Rôle : Exposition Internet (porte d'entrée)
│  └─ Services :
│     ├─ Nginx Proxy Manager (NPM) - Ports 80/443 (HTTPS reverse proxy)
│     ├─ OpenVPN - Port 1194/udp (accès distant sécurisé)
│     ├─ ddclient - DNS dynamique (OVH → elmzn.be)
│     ├─ Fail2ban - Protection bruteforce
│     ├─ UFW - Firewall (allow 80/443/1194, deny rest)
│     └─ node_exporter :9100 - Métriques Prometheus
│
└─ VM-INTRANET (ID 101) - LAN
   ├─ OS : Debian 13 (Trixie) - Installation minimale
   ├─ IP : 192.168.1.101
   ├─ RAM : 12 GB | vCPU : 3 | Disque : 40 GB (SSD)
   ├─ GPU : Intel HD 530 (passthrough PCI)
   ├─ Rôle : Services privés (JAMAIS exposés directement Internet)
   └─ Services :
      ├─ Jellyfin :8096 - Streaming vidéo/musique (transcodage HW)
      ├─ Immich :2283 - Gestion photos + app mobile
      ├─ PostgreSQL :5432 - DB Immich
      ├─ Redis - Cache Immich
      ├─ Prometheus :9090 - Collecte métriques
      ├─ Grafana :3000 - Dashboards monitoring
      ├─ Restic - Backups chiffrés AES-256
      └─ UFW - Firewall (allow depuis EXTRANET + LAN uniquement)
```

### **Plan d'adressage IP**
```
192.168.1.1   → Box Internet (gateway)
192.168.1.100 → Proxmox VE host (web UI :8006)
192.168.1.111 → VM-EXTRANET (NPM :80/443, OpenVPN :1194)
192.168.1.101 → VM-INTRANET (Jellyfin, Immich, Grafana, etc.)
192.168.1.x   → Devices famille (TV, PC, smartphones)
```

### **Accès Proxmox**
```bash
# Web UI Proxmox
https://192.168.1.100:8006

# SSH hôte Proxmox
ssh root@192.168.1.100

# Commandes VM depuis Proxmox
qm list                    # Lister VMs
qm start 100               # Démarrer VM-EXTRANET
qm start 101               # Démarrer VM-INTRANET
qm shutdown 100            # Arrêter gracefully
qm status 100              # Status VM
```

### **Isolation réseau**
```
Internet (WAN)
    ↓
Box Internet (192.168.1.1)
├─ Port forwarding UNIQUEMENT :
│  ├─ 80/tcp → 192.168.1.111:80     (VM-EXTRANET NPM)
│  ├─ 443/tcp → 192.168.1.111:443   (VM-EXTRANET NPM)
│  └─ 1194/udp → 192.168.1.111:1194 (VM-EXTRANET OpenVPN)
│
└─ LAN 192.168.1.0/24
   ├─ 192.168.1.1   (Box Internet - gateway)
   ├─ 192.168.1.100 (Proxmox host)
   ├─ 192.168.1.111 (VM-EXTRANET) ← Exposée Internet
   ├─ 192.168.1.101 (VM-INTRANET) ← JAMAIS exposée directement
   └─ 192.168.1.x   (devices famille)

Sécurité : Defense in depth (6 couches)
1. Box firewall (ports 80/443/1194 ONLY → .111)
2. Proxmox firewall (Datacenter + VM + Node)
3. VM-EXTRANET UFW (allow public ports)
4. VM-INTRANET UFW (deny all incoming sauf EXTRANET + LAN)
5. Fail2ban (auto-ban bruteforce)
6. Application auth (user accounts)
```

---

## 🌐 Réseau & DNS

### **Configuration actuelle**
```
Domaine public : elmzn.be (OVH Cloud)
DNS dynamique : ddclient (VM-EXTRANET) → OVH API

Sous-domaines configurés :
├─ media.elmzn.be → Jellyfin (via NPM sur .111)
├─ photos.elmzn.be → Immich (via NPM sur .111)
├─ grafana.elmzn.be → Grafana (via NPM sur .111, access list LAN+VPN)
└─ vpn.elmzn.be → OpenVPN (port 1194 sur .111)

Flux d'accès Internet :
Internet → elmzn.be (DNS OVH) → IP publique box
       → Port forward 80/443 → 192.168.1.111 (VM-EXTRANET NPM)
       → Reverse proxy interne → 192.168.1.101 (VM-INTRANET services)

Flux d'accès LAN (optimisé) :
TV/PC LAN → http://192.168.1.101:8096 (direct Jellyfin, pas de NPM)

Flux d'accès VPN :
Client distant → vpn.elmzn.be:1194 (OpenVPN sur .111)
              → Tunnel 10.8.0.x
              → Accès complet LAN 192.168.1.0/24 + Proxmox (.100)
```

### **Split DNS (recommandé, à implémenter)**
```
Pi-hole / AdGuard Home (LXC Proxmox)
├─ Depuis LAN : media.elmzn.be → 192.168.1.101 (direct)
└─ Depuis Internet : media.elmzn.be → IP publique (via NPM .111)

Avantage : Bypass NPM en interne = gain latence
```

---

## 🐳 Services Docker

### **VM-EXTRANET (docker-compose.extranet.yml)**
```yaml
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    ports:
      - "80:80"
      - "443:443"
      - "81:81"  # Dashboard (LAN only)
    volumes:
      - /mnt/appdata/npm/data:/data
      - /mnt/appdata/npm/letsencrypt:/etc/letsencrypt
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    restart: unless-stopped
```

**Services non-Docker (systemd) :**
- OpenVPN Access Server (systemd service)
- ddclient (systemd service)
- Fail2ban (systemd service)

### **VM-INTRANET (docker-compose.intranet.yml)**
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    ports:
      - "8096:8096"
    devices:
      - /dev/dri:/dev/dri  # GPU QuickSync
    volumes:
      - /mnt/appdata/jellyfin/config:/config
      - /mnt/appdata/jellyfin/cache:/cache
      - /mnt/media:/media:ro
    restart: unless-stopped

  immich:
    image: ghcr.io/immich-app/immich-server:release
    ports:
      - "2283:3001"
    volumes:
      - /mnt/photos:/usr/src/app/upload
    environment:
      - DB_HOSTNAME=postgres
      - REDIS_HOSTNAME=redis
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    ports:
      - "5432:5432"
    volumes:
      - /mnt/postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=immich
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=immich
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - /mnt/appdata/prometheus:/prometheus
      - /mnt/appdata/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - /mnt/appdata/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    restart: unless-stopped
```

---

## 🔒 Sécurité (configuration actuelle)

### **Pare-feu UFW - VM-EXTRANET (192.168.1.111)**
```bash
ufw default deny incoming
ufw default allow outgoing

# SSH depuis LAN uniquement
ufw allow from 192.168.1.0/24 to any port 22

# Services publics (Internet)
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 1194/udp

# Communication avec VM-INTRANET
ufw allow from 192.168.1.101
ufw allow to 192.168.1.101

ufw enable
```

### **Pare-feu UFW - VM-INTRANET (192.168.1.101)**
```bash
ufw default deny incoming
ufw default allow outgoing

# SSH depuis LAN uniquement
ufw allow from 192.168.1.0/24 to any port 22

# Services depuis VM-EXTRANET (NPM)
ufw allow from 192.168.1.111 to any port 8096  # Jellyfin
ufw allow from 192.168.1.111 to any port 2283  # Immich
ufw allow from 192.168.1.111 to any port 9090  # Prometheus
ufw allow from 192.168.1.111 to any port 3000  # Grafana

# Accès LAN direct (famille)
ufw allow from 192.168.1.0/24 to any port 8096  # Jellyfin
ufw allow from 192.168.1.0/24 to any port 2283  # Immich
ufw allow from 192.168.1.0/24 to any port 3000  # Grafana

ufw enable
```

---

## 💾 Backups (Restic - configuration actuelle)

```bash
# Repo local
RESTIC_REPOSITORY=/mnt/backups/restic-repo
RESTIC_PASSWORD_FILE=/etc/restic/passwd

# Rétention
--keep-daily 7
--keep-weekly 4
--keep-monthly 6

# Données sauvegardées
/mnt/appdata      # Configs Docker (quotidien)
/mnt/postgres     # DB Immich dump (quotidien)
/mnt/photos       # Photos Immich (hebdomadaire)
/mnt/media        # Vidéos Jellyfin (mensuel)

# Scripts
/scripts/backup.sh    # Backup + prune
/scripts/restore.sh   # Restore validé
```

---

## 📊 Monitoring (Prometheus + Grafana)

### **Prometheus targets (prometheus.yml)**
```yaml
scrape_configs:
  - job_name: 'node-extranet'
    static_configs:
      - targets: ['192.168.1.111:9100']
  
  - job_name: 'node-intranet'
    static_configs:
      - targets: ['192.168.1.101:9100']
  
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

### **Dashboards Grafana configurés**
- Node Exporter Full (ID: 1860)
- Docker & System Monitoring (ID: 893)
- Custom: media-server.json

---

## 🎯 Décisions techniques clés (ADR)

| # | Décision | Choix | Raison |
|---|----------|-------|--------|
| 001 | Hyperviseur | Proxmox VE 8.4 | Open-source, GPU passthrough, web UI |
| 002 | Orchestration | Docker Compose | Portabilité, standard DevOps |
| 003 | Reverse proxy | **Nginx Proxy Manager (NPM)** | GUI simple, Let's Encrypt auto (remplace Traefik testé initialement) |
| 004 | Filesystem | ZFS | Intégrité, snapshots (16 GB RAM OK) |
| 005 | Backups | Restic | Chiffrement AES-256, multi-backend |
| 006 | Monitoring | Prometheus + Grafana | Standard, léger, extensible |
| 007 | Stockage | SSD (perf) / HDD (capacité) | Optimise durée de vie + coûts |
| 008 | Architecture | **2 VMs (EXTRANET + INTRANET)** | Isolation sécurité, surface d'attaque réduite |
| 009 | OS invité | Debian 13 (Trixie) | Cohérence Proxmox, légèreté (800 MB idle) |
| 010 | DNS | OVH + ddclient | Domaine public elmzn.be, DDNS automatique |

---

## 🚧 État du projet (03/11/2025)

### **Infrastructure**
- ✅ Proxmox VE 8.4 installé bare-metal (Windows 11 effacé)
- ✅ ZFS configuré (tank-ssd + tank-hdd)
- ✅ VM-EXTRANET déployée (Debian 13, IP 192.168.1.111)
- ✅ VM-INTRANET déployée (Debian 13, IP 192.168.1.101)
- ✅ GPU passthrough configuré (Intel HD 530)
- ✅ DNS dynamique OVH opérationnel (elmzn.be)
- ✅ OpenVPN fonctionnel
- ✅ NPM reverse proxy configuré

### **Services**
- ✅ Jellyfin opérationnel (transcodage HW QuickSync)
- ✅ Immich déployé + app mobile connectée
- ✅ PostgreSQL 16 (DB Immich)
- ✅ Prometheus + Grafana monitoring
- ✅ Restic backups configurés et testés
- ⚠️ Immich ML désactivé (manque RAM, réactiver si upgrade 24-32 GB)

### **Documentation**
- ✅ README.md corrigé (architecture réelle)
- ✅ ADR 001-010 complets
- ✅ SETUP.md guide installation (Phases 1-10)
- ✅ CHEATSHEET.md commandes complètes
- ✅ .env.example créé
- ✅ .gitignore amélioré
- ✅ Makefile automatisation
- ✅ LICENSE (MIT)
- ⚠️ Screenshots UI à ajouter (optionnel portfolio)

---

## 🔄 Prochaines étapes

### **Court terme (cette semaine)**
1. ⚠️ Tester restore Restic complet (validation backup)
2. ⚠️ Optimiser NPM (timeouts, rate limiting)
3. ⚠️ Implémenter Split DNS (Pi-hole LXC) - optionnel
4. ⚠️ Screenshots UI (Jellyfin, Immich, Grafana) - portfolio

### **Moyen terme (1-3 mois)**
1. Upgrade HDD 500 GB → 2 To
2. Barrette RAM 8 GB (dual channel 16 GB → 24 GB total)
3. Cloudflare Tunnel (alternative OpenVPN)
4. WAF devant NPM (ModSecurity)

### **Long terme (6-12 mois)**
1. VM-BACKUP dédiée (Proxmox Backup Server)
2. Cluster Proxmox (si 2ème machine)
3. Migration Immich ML (si RAM suffisante)

---

## 🐛 Problèmes connus

### **Performance**
- ⚠️ Single channel RAM → perte ~10-15% perf GPU/ML
  - **Solution :** Ajouter barrette identique 8 GB DDR4-2133 (dual channel)

### **Stockage**
- ⚠️ HDD 500 GB limite (~360 GB utilisés / 450 GB dispo)
  - **Solution :** Upgrade prévu 2 To dans 6-12 mois

### **Services**
- ⚠️ Immich ML désactivé (consomme trop RAM actuellement)
  - **Solution :** Réactiver si upgrade 24-32 GB RAM

---

## ⚡ Commandes rapides (usage quotidien)

### **Accès infrastructure**
```bash
# Proxmox Web UI
https://192.168.1.100:8006

# SSH hôte Proxmox
ssh root@192.168.1.100

# SSH VM-EXTRANET
ssh root@192.168.1.111

# SSH VM-INTRANET
ssh user@192.168.1.101
```

### **Docker (via Makefile)**
```bash
# Depuis machine locale (avec Makefile configuré pour .111 et .101)
make up              # Start tous services
make down            # Stop tous services
make logs            # Voir logs (choix VM)
make status          # Status services
make backup          # Backup Restic
make test            # Smoke tests
```

### **Docker (manuel)**
```bash
# VM-EXTRANET (192.168.1.111)
ssh root@192.168.1.111
cd /opt/extranet
docker compose logs -f npm
docker compose restart npm

# VM-INTRANET (192.168.1.101)
ssh user@192.168.1.101
cd /opt/intranet
docker compose logs -f jellyfin
docker compose restart immich
```

### **Monitoring**
```bash
# ZFS status
zpool status

# UFW status
ufw status verbose

# Services actifs
systemctl status openvpn@server
systemctl status ddclient
systemctl status fail2ban
```

---

## 📞 Ressources & liens

### **Documentation officielle**
- Proxmox : https://pve.proxmox.com/wiki/
- Docker Compose : https://docs.docker.com/compose/
- Jellyfin : https://jellyfin.org/docs/
- Immich : https://immich.app/docs/
- Nginx Proxy Manager : https://nginxproxymanager.com/
- Restic : https://restic.readthedocs.io/

### **Repo GitHub**
- URL : https://github.com/dexteee-r/media-server-home
- Branch : main
- Score portfolio : 8.8/10 (9.8/10 avec screenshots)

### **Communauté**
- r/selfhosted : https://reddit.com/r/selfhosted
- r/Proxmox : https://reddit.com/r/Proxmox
- Discord Immich : https://discord.gg/immich

---

## 🎯 Contexte pour l'IA

**Session actuelle : Développement/Configuration/Mise en place**

L'infrastructure de base est **déployée et fonctionnelle**. Le focus maintenant est sur :
- Optimisation des services existants
- Configuration fine (timeouts NPM, tuning Prometheus, etc.)
- Tests de charge et performances
- Automatisation (scripts, monitoring, alerting)
- Debugging éventuel

**Historique complet dans :** `docs/journal_de_bord.md`

**Dernière mise à jour :** 03/11/2025 (après correction IP)

---

**FIN DU CONTEXTE** ✅