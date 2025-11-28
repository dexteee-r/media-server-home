# GUIDE CONFIGURATION : MACHINE #1 (EXTRANET NODE)

## OBJECTIF
Reconfigurer Machine #1 actuelle pour focus EXTRANET uniquement (DMZ)

---

## ÉTAPE 1 : Audit Configuration Actuelle (30 min)

### 1.1 - Backup Complet Avant Modifications
```bash
# SSH vers Machine #1 (OptiPlex)
ssh root@192.168.1.100

# Backup VMs actuelles
vzdump 100 --storage local --mode snapshot --compress zstd
vzdump 101 --storage local --mode snapshot --compress zstd

# Backup configs Proxmox
tar czf /root/proxmox-backup-$(date +%Y%m%d).tar.gz \
  /etc/pve \
  /etc/network/interfaces \
  /etc/hosts

# Backup Docker configs
cd /opt
tar czf /root/docker-configs-backup-$(date +%Y%m%d).tar.gz \
  extranet/ intranet/

# Copier backups vers Machine #2 (via SCP)
scp /root/*backup*.tar.gz root@192.168.1.101:/mnt/backups/machine1/
```

### 1.2 - Documenter État Actuel
```bash
# Lister VMs existantes
qm list

# Vérifier stockage
df -h
zpool status

# Lister containers Docker
docker ps -a

# Sauvegarder état dans fichier
cat > /root/etat-avant-modif.txt << EOF
Date: $(date)
VMs: $(qm list)
Storage: $(df -h)
Docker: $(docker ps --format "table {{.Names}}\t{{.Status}}")
Network: $(ip -4 addr show vmbr0)
EOF
```

---

## ÉTAPE 2 : Migration Services INTRANET → Machine #2 (1h)

### 2.1 - Arrêter Services INTRANET sur M1
```bash
# Arrêter VM-INTRANET
qm stop 101

# Arrêter Docker INTRANET (si direct sur host)
cd /opt/intranet
docker-compose down
```

### 2.2 - Exporter Données Critiques
```bash
# Jellyfin config (si utilisé)
tar czf /tmp/jellyfin-config.tar.gz /mnt/appdata/jellyfin/

# Immich photos (si existe)
rsync -avz --progress /mnt/photos/ root@192.168.1.101:/mnt/photos/

# PostgreSQL dump (si DB locale)
docker exec postgres pg_dumpall -U postgres > /tmp/postgres-dump.sql
scp /tmp/postgres-dump.sql root@192.168.1.101:/mnt/backups/
```

### 2.3 - Désactiver VM-INTRANET
```bash
# Désactiver autostart
qm set 101 --onboot 0

# Optionnel : supprimer VM (après validation M2)
# qm destroy 101
```

---

## ÉTAPE 3 : Reconfigurer Machine #1 en EXTRANET Pure (30 min)

### 3.1 - Nettoyer Services Inutiles
```bash
# Garder UNIQUEMENT services EXTRANET
cd /opt/extranet

# Vérifier docker-compose.yml
cat docker-compose.yml

# Devrait contenir SEULEMENT :
# - nginx-proxy-manager
# - node-exporter (monitoring)
# - fail2ban (si conteneurisé)

# Supprimer dossier intranet (après backup)
rm -rf /opt/intranet
```

### 3.2 - Optimiser Allocation Ressources
```bash
# VM-EXTRANET peut utiliser plus de RAM maintenant
qm set 100 --memory 6144  # Passe de 4 GB à 6 GB

# Ajouter vCPU si besoin
qm set 100 --cores 3      # Passe de 2 à 3 cores

# Vérifier config
qm config 100
```

### 3.3 - Configurer Reverse Proxy vers M2
```bash
# SSH vers VM-EXTRANET
ssh root@192.168.1.111

# Ajouter routes NPM vers services M2 :
# Via Web UI NPM (http://192.168.1.111:81)

Proxy Host 1 :
├─ Domain : photos.elmzn.be
├─ Scheme : http
├─ Forward Hostname : 192.168.1.101
├─ Forward Port : 2283
├─ SSL : Request Let's Encrypt
└─ Force SSL : Yes

Proxy Host 2 :
├─ Domain : files.elmzn.be
├─ Scheme : http
├─ Forward Hostname : 192.168.1.101
├─ Forward Port : 8080
├─ SSL : Request Let's Encrypt
└─ Force SSL : Yes

Proxy Host 3 :
├─ Domain : grafana.elmzn.be
├─ Scheme : http
├─ Forward Hostname : 192.168.1.101
├─ Forward Port : 3000
├─ SSL : Request Let's Encrypt
├─ Force SSL : Yes
└─ Access List : LAN + VPN only (sécurité)
```

### 3.4 - Configurer Firewall UFW VM-EXTRANET
```bash
# SSH VM-EXTRANET
ssh root@192.168.1.111

# Reset UFW (clean slate)
ufw --force reset

# Règles de base
ufw default deny incoming
ufw default allow outgoing

# SSH depuis LAN uniquement
ufw allow from 192.168.1.0/24 to any port 22

# Services publics
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 1194/udp  # OpenVPN

# Communication avec M2 INTRANET
ufw allow from 192.168.1.101
ufw allow to 192.168.1.101

# Activer
ufw enable

# Vérifier
ufw status verbose
```

---

## ÉTAPE 4 : Tests Communication M1 ↔ M2 (30 min)

### 4.1 - Test Ping Basique
```bash
# Depuis M1 Proxmox host
ping 192.168.1.101  # M2 host → OK
ping 192.168.1.101  # M2 VM-INTRANET → OK

# Depuis M1 VM-EXTRANET
ssh root@192.168.1.111
ping 192.168.1.101  # M2 → OK
```

### 4.2 - Test Reverse Proxy NPM → M2
```bash
# Depuis VM-EXTRANET
curl -I http://192.168.1.101:2283  # Immich → HTTP 200
curl -I http://192.168.1.101:8080  # Nextcloud → HTTP 200
curl -I http://192.168.1.101:3000  # Grafana → HTTP 302 (login)
```

### 4.3 - Test Accès Externe (depuis smartphone 4G)
```bash
# Tester depuis navigateur mobile (pas WiFi maison)
https://photos.elmzn.be      # → Doit charger Immich
https://files.elmzn.be       # → Doit charger Nextcloud
https://grafana.elmzn.be     # → Doit charger Grafana (si pas access list)
```

---

## ÉTAPE 5 : Configuration Backups M2 → M1 (30 min)

### 5.1 - Préparer Storage Backup sur M1
```bash
# SSH M1 Proxmox host
ssh root@192.168.1.100

# Créer dataset ZFS backup (si HDD 500 GB existe)
zfs create tank-hdd/backups-m2

# Ou créer dossier simple
mkdir -p /mnt/backups-m2
chmod 700 /mnt/backups-m2
```

### 5.2 - Configurer Restic depuis M2
```bash
# SSH M2 VM-INTRANET
ssh root@192.168.1.101

# Installer Restic
apt install restic -y

# Initialiser repo distant (via SSH)
export RESTIC_REPOSITORY=sftp:root@192.168.1.100:/mnt/backups-m2
export RESTIC_PASSWORD="CHANGE_ME_STRONG_PASSWORD"

restic init

# Tester backup
restic backup /mnt/photos --tag photos-test
restic backup /opt/intranet --tag configs-test

# Lister snapshots
restic snapshots
```

### 5.3 - Automatiser Backups (Cron)
```bash
# Créer script backup
cat > /root/backup-to-m1.sh << 'EOF'
#!/bin/bash
export RESTIC_REPOSITORY=sftp:root@192.168.1.100:/mnt/backups-m2
export RESTIC_PASSWORD="CHANGE_ME_STRONG_PASSWORD"

# Backup photos (hebdomadaire)
restic backup /mnt/photos --tag photos

# Backup configs (quotidien)
restic backup /opt/intranet --tag configs

# Backup PostgreSQL (quotidien)
docker exec postgres pg_dumpall -U postgres > /tmp/postgres.sql
restic backup /tmp/postgres.sql --tag database
rm /tmp/postgres.sql

# Pruning (garder 7 daily, 4 weekly, 6 monthly)
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
EOF

chmod +x /root/backup-to-m1.sh

# Tester script
/root/backup-to-m1.sh

# Ajouter cron (tous les jours 2h du matin)
crontab -e
# Ajouter ligne :
0 2 * * * /root/backup-to-m1.sh >> /var/log/backup-m1.log 2>&1
```

---

## ÉTAPE 6 : Services Additionnels EXTRANET (optionnel)

### 6.1 - Uptime Kuma (Monitoring Uptime)
```bash
# SSH VM-EXTRANET
ssh root@192.168.1.111

cd /opt/extranet

# Ajouter au docker-compose.yml
cat >> docker-compose.yml << 'EOF'

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    ports:
      - "3001:3001"
    volumes:
      - ./uptime-kuma:/app/data
    restart: unless-stopped
EOF

# Démarrer
docker-compose up -d uptime-kuma

# Accès Web UI
http://192.168.1.111:3001

# Configurer monitoring :
# - Jellyfin : http://192.168.1.101:8096
# - Immich : http://192.168.1.101:2283
# - Nextcloud : http://192.168.1.101:8080
# - Grafana : http://192.168.1.101:3000
```

---

## ✅ CHECKLIST FINALE MACHINE #1

Configuration EXTRANET complète si :
- [x] Services INTRANET migrés vers M2
- [x] VM-EXTRANET optimisée (6 GB RAM, 3 vCPU)
- [x] Reverse proxy NPM vers M2 configuré
- [x] UFW firewall restrictif actif
- [x] Tests ping M1 ↔ M2 OK
- [x] Tests reverse proxy vers M2 OK
- [x] Accès externe (4G) vers services M2 OK
- [x] Backups M2 → M1 automatisés
- [x] Uptime Kuma monitoring (optionnel)

Si tout ✅ → Architecture complète opérationnelle ! 🎉

---

## 📊 RÉSUMÉ ARCHITECTURE FINALE

```
Internet
   ↓
Box (192.168.1.1)
   ↓ (ports 80/443/1194 forward)
   ↓
M1 EXTRANET (192.168.1.111)
├─ Nginx Proxy Manager (reverse proxy)
├─ OpenVPN (accès distant)
├─ Fail2ban (protection)
├─ Uptime Kuma (monitoring)
└─ Proxy vers ↓

M2 INTRANET (192.168.1.101)
├─ Immich (photos 4 TB)
├─ Nextcloud (fichiers 4 TB)
├─ Grafana (monitoring)
├─ VM-DEV-LINUX (lab)
└─ VM-DEV-WINDOWS (lab)

Backups : M2 → M1 (Restic quotidien)
```

Temps total implémentation : **6-8 heures** (sur 1-2 weekends)
