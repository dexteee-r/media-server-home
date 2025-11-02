# 🖥️ VM-EXTRANET — Services exposés (Proxy / VPN)

## 📘 Contexte

La **VM-EXTRANET** constitue la **zone DMZ (Demilitarized Zone)** du projet *media-server-home*.  
Elle héberge tous les services accessibles depuis le réseau local et (le cas échéant) depuis Internet via VPN ou reverse proxy.

L’objectif de cette VM est de **filtrer et sécuriser** l’accès aux services internes, sans jamais héberger de données sensibles.  
Les flux entre l’EXTRANET et l’INTRANET sont strictement contrôlés via le pare-feu Proxmox et UFW.

---

## ⚙️ Spécifications techniques

| Élément | Détail |
|----------|--------|
| **Nom VM** | `vm-extranet` |
| **OS** | Debian 12 (Bookworm) |
| **Réseau Proxmox** | `vmbr1` (DMZ / EXTRANET) |
| **CPU / RAM** | 2 vCPU, 2–4 Go RAM |
| **Disque virtuel** | 20 Go SSD (pas de stockage médias) |
| **IP statique** | `10.10.0.10` (exemple, DMZ) |
| **Pare-feu Proxmox** | Activé |
| **Snapshots** | Hebdomadaires |
| **Sauvegardes** | Configuration uniquement (via Restic distant) |

---

## 🌐 Services hébergés

| Service | Description | Port(s) | Docker / Natif |
|----------|--------------|----------|----------------|
| **Nginx Proxy Manager (NPM)** | Reverse proxy HTTPS / gestion certificats Let’s Encrypt | 80, 443 | Docker |
| **OpenVPN** | Serveur VPN pour accès distant chiffré | 1194/UDP | Natif ou Docker |
| **node_exporter** | Export métriques système (Prometheus) | 9100 | Docker |
| **Fail2ban + UFW** | Protection brute-force / pare-feu local | — | Natif |

> ⚠️ Aucun service de stockage ni base de données ne tourne sur cette VM.

---

## 🔒 Sécurité & réseau

### Topologie
- Connectée au bridge Proxmox **`vmbr1`** (DMZ).
- Communique avec la VM-INTRANET via règles firewall précises :
  - HTTPS → Jellyfin / Immich
  - Prometheus (scrape metrics)
- Aucun accès direct vers ZFS ou Postgres.

### Pare-feu UFW
```bash
# Configuration UFW - VM-EXTRANET
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp     # NPM HTTP
sudo ufw allow 443/tcp    # NPM HTTPS
sudo ufw allow 1194/udp   # OpenVPN
sudo ufw allow from 192.168.1.0/24 to any port 9100 proto tcp comment 'Prometheus metrics (INTRANET)'
sudo ufw enable
````

### Proxmox Firewall (niveau VM)

| Direction | Action | Port(s)           | Source                 | Commentaire               |
| --------- | ------ | ----------------- | ---------------------- | ------------------------- |
| IN        | ACCEPT | 80, 443, 1194/UDP | LAN / Internet         | Trafic utilisateurs / VPN |
| IN        | ACCEPT | 9100              | INTRANET (192.168.x.x) | Monitoring                |
| IN        | DROP   | *                 | *                      | Tout le reste             |

---

## 📦 Volumes Docker

| Volume                              | Destination              | Usage                              |
| ----------------------------------- | ------------------------ | ---------------------------------- |
| `/mnt/tank/appdata/npm`             | `/data`                  | Données NPM (users, routes, certs) |
| `/mnt/tank/appdata/npm/letsencrypt` | `/etc/letsencrypt`       | Certificats SSL                    |
| `/mnt/tank/appdata/node_exporter`   | `/var/lib/node_exporter` | Export metrics (facultatif)        |

> ⚠️ Ces volumes ne contiennent pas de données critiques et peuvent être recréés à partir du code source + backups.

---

## 🧰 Maintenance & supervision

| Tâche                    | Fréquence         | Commande / Outil                |
| ------------------------ | ----------------- | ------------------------------- |
| Mise à jour système      | Hebdo             | `apt update && apt upgrade -y`  |
| MàJ conteneurs           | Auto (Watchtower) | `docker logs watchtower`        |
| Vérification certificats | Hebdo             | Interface NPM                   |
| Vérification VPN         | Hebdo             | `systemctl status openvpn`      |
| Monitoring               | Continu           | Scrape Prometheus (VM-INTRANET) |

---

## 🔁 Sauvegardes

| Type                         | Cible                                            | Fréquence | Outil                   |
| ---------------------------- | ------------------------------------------------ | --------- | ----------------------- |
| Config NPM                   | `/mnt/tank/backups/npm-config` (INTRANET Restic) | Hebdo     | `rsync` via SSH         |
| OpenVPN keys                 | `/mnt/tank/backups/openvpn` (INTRANET Restic)    | Mensuel   | Script automatisé       |
| Docker volumes non sensibles | —                                                | —         | Recréables à la demande |

> Les sauvegardes sont effectuées **depuis la VM-INTRANET** pour éviter toute exposition.

---

## 🧠 Notes techniques

* Les **certificats Let’s Encrypt** sont gérés automatiquement par NPM.
* **OpenVPN** utilise un chiffrement **AES-256-CBC** et une clé DH de 4096 bits.
* Les fichiers `.ovpn` sont exportés via script local et transférés manuellement aux utilisateurs autorisés.
* Les logs VPN et NPM sont montés dans `/mnt/tank/appdata/logs/extranet` pour supervision.

---

## 🧩 Roadmap d’évolution

* [ ] Ajouter authentification LDAP (optionnelle) pour NPM.
* [ ] Étudier migration future vers **Traefik** (automatisation Docker labels).
* [ ] Intégrer Promtail pour logs unifiés vers Grafana Loki.

---

🗓️ **Journal de bord – 02/11/2025**
Création de la VM-EXTRANET documentée.
Contient NPM, OpenVPN, node_exporter, UFW + Fail2ban.
Flux restreints vers INTRANET (HTTPS et metrics).
Aucune donnée critique locale. Sauvegardes hebdomadaires via Restic (INTRANET).


