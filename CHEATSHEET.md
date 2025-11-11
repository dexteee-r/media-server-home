# CHEATSHEET.md - Commandes rapides Homelab

## 📑 Table des matières

- [Proxmox VE](#proxmox-ve)
- [Multi-VM](#multi-vm)
- [Docker](#docker)
- [Nginx Proxy Manager](#nginx-proxy-manager)
- [OpenVPN](#openvpn)
- [DNS dynamique](#dns-dynamique)
- [Firewall UFW](#firewall-ufw)
- [Monitoring](#monitoring)
- [Backups](#backups)
- [Réseau](#réseau)
- [Troubleshooting](#troubleshooting)

---

## Proxmox VE

### Gestion VMs

```bash
# Lister VMs
qm list

# Démarrer VM
qm start 100  # VM-EXTRANET
qm start 101  # VM-INTRANET

# Arrêter VM (graceful)
qm shutdown 100

# Arrêter VM (force)
qm stop 100

# Redémarrer VM
qm reboot 100

# Status VM
qm status 100

# Console VM
qm terminal 100

# Cloner VM
qm clone 100 200 --name VM-TEST

# Supprimer VM
qm destroy 100
```

### Snapshots

```bash
# Créer snapshot
qm snapshot 100 backup-2025-11-02

# Lister snapshots
qm listsnapshot 100

# Restaurer snapshot
qm rollback 100 backup-2025-11-02

# Supprimer snapshot
qm delsnapshot 100 backup-2025-11-02
```

### Stockage

```bash
# Lister stockages
pvesm status

# Espace disque VMs
qm disk rescan

# Redimensionner disque VM
qm resize 100 scsi0 +10G

# Lister backups
vzdump list
```

### Réseau

```bash
# Config réseau
cat /etc/network/interfaces

# Redémarrer réseau
systemctl restart networking

# Tester connectivité
ping -c 4 192.168.1.100

# Lister bridges
ip link show type bridge
```

---

## Multi-VM

### Accès SSH VMs

```bash
# VM-EXTRANET (192.168.1.100)
ssh admin@192.168.1.100

# VM-INTRANET (192.168.1.101)
ssh admin@192.168.1.101

# Copier fichier vers VM
scp fichier.txt admin@192.168.1.100:~/

# Copier fichier depuis VM
scp admin@192.168.1.101:~/fichier.txt .

# SSH sans mot de passe (clé publique)
ssh-copy-id admin@192.168.1.100
```

### Exécution commandes distantes

```bash
# Commande unique
ssh admin@192.168.1.100 'docker ps'

# Script distant
ssh admin@192.168.1.100 'bash -s' < script.sh

# Commande sur plusieurs VMs
for vm in 100 101; do
  ssh admin@192.168.1.$vm 'uptime'
done
```

### Monitoring multi-VM

```bash
# Status toutes VMs
for vm in 100 101; do
  echo "=== VM 192.168.1.$vm ==="
  ssh admin@192.168.1.$vm 'hostname && uptime && df -h /'
done

# Docker status toutes VMs
for vm in 100 101; do
  echo "=== VM 192.168.1.$vm ==="
  ssh admin@192.168.1.$vm 'docker ps --format "table {{.Names}}\t{{.Status}}"'
done

# Logs centralisés (via Grafana Loki)
# TODO: Implémenter Loki pour logs multi-VM
```

---

## Docker

### Gestion containers

```bash
# Lister containers actifs
docker ps

# Lister tous containers (y compris arrêtés)
docker ps -a

# Démarrer container
docker start jellyfin

# Arrêter container
docker stop jellyfin

# Redémarrer container
docker restart jellyfin

# Supprimer container
docker rm jellyfin

# Logs container (temps réel)
docker logs -f jellyfin

# Logs (100 dernières lignes)
docker logs --tail 100 jellyfin

# Stats containers
docker stats
```

### Docker Compose

```bash
# Démarrer stack
docker compose up -d

# Arrêter stack
docker compose down

# Redémarrer stack
docker compose restart

# Voir logs stack
docker compose logs -f

# Rebuild et redémarrer
docker compose up -d --build

# Arrêter et supprimer volumes
docker compose down -v
```

### Images

```bash
# Lister images
docker images

# Télécharger image
docker pull jellyfin/jellyfin:latest

# Supprimer image
docker rmi jellyfin/jellyfin:latest

# Supprimer images non utilisées
docker image prune -a

# Mettre à jour toutes images
docker compose pull
docker compose up -d
```

### Volumes

```bash
# Lister volumes
docker volume ls

# Inspecter volume
docker volume inspect jellyfin_config

# Supprimer volume
docker volume rm jellyfin_config

# Supprimer volumes non utilisés
docker volume prune
```

### Réseau Docker

```bash
# Lister réseaux
docker network ls

# Inspecter réseau
docker network inspect homelab-net

# Connecter container à réseau
docker network connect homelab-net jellyfin

# Déconnecter container
docker network disconnect homelab-net jellyfin
```

---

## Nginx Proxy Manager

### Accès interface

```bash
# URL admin
http://192.168.1.100:81

# Login par défaut (1er accès)
# Email: admin@example.com
# Password: changeme
```

### Gestion via Docker

```bash
# SSH VM-EXTRANET
ssh admin@192.168.1.100
cd ~/npm

# Logs NPM
docker compose logs -f npm

# Redémarrer NPM
docker compose restart npm

# Backup config NPM
tar -czf npm-backup-$(date +%Y%m%d).tar.gz data/ letsencrypt/

# Restaurer config NPM
tar -xzf npm-backup-20251102.tar.gz
docker compose up -d
```

### Certificats SSL

```bash
# Vérifier certificats Let's Encrypt
docker exec npm ls -lh /etc/letsencrypt/live/

# Renouveler certificats manuellement
docker exec npm certbot renew

# Tester expiration certificats
openssl s_client -connect media.elmzn.be:443 -servername media.elmzn.be </dev/null 2>/dev/null | \
  openssl x509 -noout -dates

# Certificat wildcard (DNS-01 challenge OVH)
docker exec -it npm bash
pip install certbot-dns-ovh
certbot certonly \
  --dns-ovh \
  --dns-ovh-credentials /etc/letsencrypt/ovhapi.ini \
  -d elmzn.be \
  -d *.elmzn.be
```

### Proxy Hosts (CLI)

```bash
# Backup DB SQLite NPM
docker exec npm sqlite3 /data/database.sqlite ".backup /data/backup.db"

# Exporter proxy hosts (JSON)
docker exec npm sqlite3 /data/database.sqlite \
  "SELECT * FROM proxy_host;" > proxy_hosts.txt

# Restaurer DB
docker exec npm cp /data/backup.db /data/database.sqlite
docker compose restart npm
```

### Logs NPM

```bash
# Logs access (requêtes HTTP)
docker exec npm tail -f /data/logs/proxy-host-1_access.log

# Logs erreurs
docker exec npm tail -f /data/logs/proxy-host-1_error.log

# Logs Nginx global
docker exec npm tail -f /var/log/nginx/error.log

# Chercher IP spécifique
docker exec npm grep "192.168.1.50" /data/logs/*_access.log
```

---

## OpenVPN

### Gestion service

```bash
# SSH VM-EXTRANET
ssh admin@192.168.1.100

# Status OpenVPN
sudo systemctl status openvpnas

# Démarrer OpenVPN
sudo systemctl start openvpnas

# Arrêter OpenVPN
sudo systemctl stop openvpnas

# Redémarrer OpenVPN
sudo systemctl restart openvpnas

# Logs OpenVPN
sudo tail -f /var/log/openvpnas.log
```

### Clients VPN

```bash
# Lister clients connectés
sudo sacli --pfmt ClientSummary

# Déconnecter client
sudo sacli --user USERNAME --disconnect

# Lister utilisateurs
sudo sacli --pfmt UserPropJson UserPropGet

# Créer utilisateur
sudo sacli --user john --key prop_autologin --value true UserPropPut
sudo passwd john

# Supprimer utilisateur
sudo sacli --user john UserPropDelAll
```

### Configuration OpenVPN

```bash
# Sauvegarder config
sudo tar -czf /root/openvpn-backup-$(date +%Y%m%d).tar.gz /usr/local/openvpn_as/

# Changer port VPN
sudo sacli --key vpn.daemon.0.listen.port --value 1194 ConfigPut
sudo systemctl restart openvpnas

# Changer subnet VPN
sudo sacli --key vpn.client.routing.reroute_gw --value false ConfigPut
sudo sacli --key vpn.server.dhcp.option.domain --value elmzn.be ConfigPut
sudo systemctl restart openvpnas

# Reset mot de passe admin
sudo passwd openvpn
```

### Certificats OpenVPN

```bash
# Télécharger profil client
# URL: https://vpn.elmzn.be:943/?src=connect
# Login: [utilisateur]
# Télécharger: client.ovpn

# Importer profil (Linux)
sudo openvpn --config client.ovpn

# Importer profil (Windows)
# Copier client.ovpn dans C:\Program Files\OpenVPN\config\
# OpenVPN GUI → Right click → Connect

# Importer profil (mobile)
# OpenVPN Connect app → Import Profile → From URL
# https://vpn.elmzn.be:943/?src=connect
```

### Tests VPN

```bash
# Tester connexion VPN (avant connexion)
ping -c 4 192.168.1.100

# Connecter VPN
sudo openvpn --config client.ovpn

# Vérifier IP VPN (après connexion)
ip addr show tun0
# Doit afficher 10.8.0.x

# Tester accès LAN via VPN
ping -c 4 192.168.1.101

# Tester DNS via VPN
nslookup media.elmzn.be
```

---

## DNS dynamique

### ddclient

```bash
# SSH VM-EXTRANET
ssh admin@192.168.1.100

# Status ddclient
sudo systemctl status ddclient

# Redémarrer ddclient
sudo systemctl restart ddclient

# Logs ddclient
sudo tail -f /var/log/syslog | grep ddclient

# Test manuel MAJ
sudo ddclient -daemon=0 -debug -verbose -noquiet

# Forcer MAJ immédiate
sudo ddclient -force

# Vérifier dernière MAJ
sudo ddclient -query
```

### Tests DNS

```bash
# Vérifier résolution DNS publique
dig vpn.elmzn.be +short
# Doit afficher IP publique

# Vérifier propagation DNS mondiale
dig @8.8.8.8 vpn.elmzn.be +short
dig @1.1.1.1 vpn.elmzn.be +short

# Historique DNS (cache)
dig vpn.elmzn.be +trace

# TTL DNS
dig vpn.elmzn.be | grep -A1 "ANSWER SECTION"
# Doit afficher TTL 300 (5 min)
```

### OVH DynHost

```bash
# Tester API OVH DynHost manuellement
curl -u "elmzn.be-vpn:MOT_DE_PASSE" \
  "https://www.ovh.com/nic/update?system=dyndns&hostname=vpn.elmzn.be&myip=$(curl -s ifconfig.me)"

# Réponse attendue: good [IP]

# Vérifier DynHost (espace client OVH)
# → Domaines → elmzn.be → DynHost
# Voir dernière MAJ + IP actuelle
```

---

## Firewall UFW

### Règles de base

```bash
# Status firewall
sudo ufw status verbose

# Activer firewall
sudo ufw enable

# Désactiver firewall (temporaire)
sudo ufw disable

# Règles par défaut
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Recharger règles
sudo ufw reload
```

### Gestion règles

```bash
# Autoriser port
sudo ufw allow 22/tcp comment 'SSH'

# Autoriser depuis IP spécifique
sudo ufw allow from 192.168.1.0/24 to any port 22

# Autoriser depuis subnet VPN
sudo ufw allow from 10.8.0.0/24 to any port 8096

# Supprimer règle (par numéro)
sudo ufw status numbered
sudo ufw delete 5

# Supprimer règle (par description)
sudo ufw delete allow 8096/tcp
```

### Logs UFW

```bash
# Activer logs
sudo ufw logging on

# Logs firewall
sudo tail -f /var/log/ufw.log

# Logs bloqués (DENY)
sudo grep "UFW BLOCK" /var/log/ufw.log

# Top IPs bloquées
sudo grep "UFW BLOCK" /var/log/ufw.log | \
  awk '{print $12}' | sort | uniq -c | sort -rn | head -10
```

---

## Monitoring

### Prometheus

```bash
# SSH VM-INTRANET
ssh admin@192.168.1.101
cd ~/homelab/monitoring

# Logs Prometheus
docker compose logs -f prometheus

# Vérifier config
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Recharger config (sans redémarrage)
curl -X POST http://localhost:9090/-/reload

# Query API
curl 'http://localhost:9090/api/v1/query?query=up'

# Targets status
curl 'http://localhost:9090/api/v1/targets'
```

### Grafana

```bash
# Logs Grafana
docker compose logs -f grafana

# Reset mot de passe admin
docker exec -it grafana grafana-cli admin reset-admin-password admin123

# Backup dashboards
curl -H "Authorization: Bearer API_TOKEN" \
  http://localhost:3000/api/search > dashboards.json

# Import dashboard
# Grafana UI → Dashboards → Import → Upload JSON
```

### Node Exporter

```bash
# Status Node Exporter
sudo systemctl status node_exporter

# Redémarrer Node Exporter
sudo systemctl restart node_exporter

# Métriques brutes
curl http://localhost:9100/metrics | head -20

# Vérifier métriques spécifiques
curl http://localhost:9100/metrics | grep node_cpu_seconds_total
```

### Métriques système

```bash
# CPU usage
top -bn1 | grep "Cpu(s)"

# RAM usage
free -h

# Disk usage
df -h

# Disk I/O
iostat -x 1

# Network usage
iftop

# Docker stats
docker stats --no-stream
```

---

## Backups

### Backup manuel

```bash
# Backup VM Proxmox (snapshot)
qm snapshot 100 backup-$(date +%Y%m%d)

# Backup Docker volumes
docker run --rm \
  -v jellyfin_config:/data \
  -v $(pwd):/backup \
  alpine tar -czf /backup/jellyfin-backup-$(date +%Y%m%d).tar.gz /data

# Backup PostgreSQL (Immich)
docker exec immich-postgres pg_dump -U postgres immich > immich-backup.sql

# Backup NPM config
ssh admin@192.168.1.100 'cd ~/npm && tar -czf npm-backup.tar.gz data/ letsencrypt/'
scp admin@192.168.1.100:~/npm/npm-backup.tar.gz .
```

### Restauration

```bash
# Restaurer snapshot VM
qm rollback 100 backup-20251102

# Restaurer Docker volume
docker run --rm \
  -v jellyfin_config:/data \
  -v $(pwd):/backup \
  alpine tar -xzf /backup/jellyfin-backup-20251102.tar.gz -C /data

# Restaurer PostgreSQL
docker exec -i immich-postgres psql -U postgres immich < immich-backup.sql

# Restaurer NPM
scp npm-backup.tar.gz admin@192.168.1.100:~/npm/
ssh admin@192.168.1.100 'cd ~/npm && tar -xzf npm-backup.tar.gz && docker compose restart'
```

### Backup automatique (Restic)

```bash
# Installer Restic
sudo apt install -y restic

# Initialiser repo
restic -r /backup/restic init

# Backup
restic -r /backup/restic backup /home/admin/homelab

# Lister backups
restic -r /backup/restic snapshots

# Restaurer
restic -r /backup/restic restore latest --target /restore
```

---

## Réseau

### Diagnostique réseau

```bash
# Tester connectivité
ping -c 4 192.168.1.1

# Traceroute
traceroute 1.1.1.1

# DNS lookup
nslookup media.elmzn.be
dig media.elmzn.be

# Ports ouverts (local)
sudo netstat -tuln | grep LISTEN

# Ports ouverts (distant)
nmap -p 80,443,8096 192.168.1.101

# Tester port spécifique
telnet 192.168.1.101 8096
```

### Performance réseau

```bash
# Bande passante (iperf3)
# Serveur
iperf3 -s

# Client
iperf3 -c 192.168.1.101

# Latence
ping -c 10 192.168.1.101 | tail -1

# MTU optimal
ping -M do -s 1472 -c 1 192.168.1.101
```

---

## Troubleshooting

### Services ne démarrent pas

```bash
# Vérifier logs service
journalctl -u servicename -f

# Vérifier Docker logs
docker logs --tail 50 container_name

# Vérifier ports utilisés
sudo netstat -tuln | grep 8096

# Kill process sur port
sudo lsof -ti:8096 | xargs sudo kill -9
```

### Problèmes réseau

```bash
# Vérifier IP VM
ip addr show

# Vérifier route par défaut
ip route show

# Vérifier DNS
cat /etc/resolv.conf

# Test DNS
dig @1.1.1.1 google.com

# Redémarrer réseau
sudo systemctl restart networking
```

### Certificats SSL expirés

```bash
# Vérifier expiration
openssl s_client -connect media.elmzn.be:443 </dev/null 2>/dev/null | \
  openssl x509 -noout -dates

# Renouveler Let's Encrypt (NPM)
docker exec npm certbot renew --force-renewal

# Redémarrer NPM
docker compose -f ~/npm/docker-compose.yml restart
```

### Espace disque plein

```bash
# Vérifier espace
df -h

# Trouver gros fichiers
du -h / | sort -rh | head -20

# Nettoyer Docker
docker system prune -a --volumes

# Nettoyer logs
sudo journalctl --vacuum-time=7d

# Nettoyer APT cache
sudo apt clean
```

### Performance lente

```bash
# Vérifier CPU
top

# Vérifier RAM
free -h

# Vérifier disque I/O
iostat -x 1

# Vérifier processus lourds
ps aux --sort=-%mem | head -10

# Docker stats
docker stats
```

---

## 🔗 Liens utiles

**Documentation** :
- README : Vue d'ensemble projet
- SETUP : Installation complète
- ADR : Décisions techniques
- JOURNAL : Sessions de travail

**Interfaces web** :
- Proxmox : https://192.168.1.5:8006
- NPM : http://192.168.1.100:81
- OpenVPN : https://vpn.elmzn.be:943
- Jellyfin : https://media.elmzn.be
- Immich : https://photos.elmzn.be
- Grafana : https://grafana.elmzn.be

**Commandes rapides** :
```bash
# SSH toutes VMs
alias ssh-extranet='ssh admin@192.168.1.100'
alias ssh-intranet='ssh admin@192.168.1.101'

# Docker Compose raccourcis
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dcp='docker compose ps'

# Monitoring rapide
alias vms='qm list'
alias diskspace='df -h | grep -E "Filesystem|/$"'
alias meminfo='free -h'
```

## ZFS (Proxmox)

### Lister les pools et datasets
```bash
zfs list
zfs list -o name,quota,used,avail tank-hdd
zfs list -o name,quota,used,avail tank-ssd
```

### Gérer les quotas
```bash
# Voir quota
zfs get quota tank-hdd/photos

# Définir quota
zfs set quota=150G tank-hdd/photos

# Supprimer quota
zfs set quota=none tank-hdd/photos
```

### Snapshots
```bash
# Créer snapshot
zfs snapshot tank-hdd/photos@backup-20251111

# Lister snapshots
zfs list -t snapshot

# Restaurer snapshot
zfs rollback tank-hdd/photos@backup-20251111

# Supprimer snapshot
zfs destroy tank-hdd/photos@backup-20251111
```

## NFS

### Proxmox (serveur NFS)
```bash
# Voir exports actifs
showmount -e localhost

# Voir clients connectés
showmount -a

# Recharger exports
exportfs -ra

# Éditer exports
nano /etc/exports
```

### VMs (client NFS)
```bash
# Lister exports serveur
showmount -e 192.168.1.100

# Monter manuellement
mount -t nfs 192.168.1.100:/tank-ssd/appdata /mnt/appdata

# Démonter
umount /mnt/appdata

# Remonter tous les fstab
mount -a

# Voir montages NFS
df -h | grep 192.168.1.100
mount | grep nfs
```

## Docker VM-INTRANET

### Commandes de base
```bash
cd /opt/intranet

# Voir statut
docker compose ps

# Démarrer tous les services
docker compose up -d

# Arrêter tous les services
docker compose down

# Redémarrer un service
docker compose restart jellyfin

# Voir logs
docker compose logs -f
docker compose logs jellyfin --tail 50

# Rebuild un service
docker compose up -d --force-recreate jellyfin

# Supprimer tout et recréer
docker compose down
docker compose up -d
```

### Gestion conteneurs
```bash
# Entrer dans un conteneur
docker exec -it immich-server sh

# Voir ressources utilisées
docker stats

# Nettoyer images inutilisées
docker system prune -a
```

## VMs

### SSH
```bash
# VM-INTRANET
ssh intraadmin@192.168.1.101

# VM-EXTRANET
ssh extraadmin@192.168.1.111

# Proxmox
ssh root@192.168.1.100
```

### Gestion VMs depuis Proxmox
```bash
# Lister VMs
qm list

# Démarrer VM
qm start 100  # VM-INTRANET
qm start 101  # VM-EXTRANET

# Arrêter VM
qm shutdown 100

# Forcer arrêt
qm stop 100

# Status
qm status 100
```

## Services (URLs)

### VM-INTRANET (192.168.1.101)
```
Jellyfin:    http://192.168.1.101:8096
Immich:      http://192.168.1.101:2283
Grafana:     http://192.168.1.101:3000
Prometheus:  http://192.168.1.101:9090
NPM:         http://192.168.1.101:81
```

### Proxmox
```
Web UI:      https://192.168.1.100:8006
