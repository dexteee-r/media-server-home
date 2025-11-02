# 🖥️ VM-INTRANET — Services internes & stockage principal

## 📘 Contexte

La **VM-INTRANET** est la machine virtuelle principale du projet *media-server-home*.  
Elle héberge **tous les services internes**, les **bases de données**, ainsi que les **systèmes de stockage et sauvegarde**.  
Aucun accès direct depuis Internet n’est autorisé : toutes les connexions passent par la **VM-EXTRANET** via proxy HTTPS ou VPN.

Cette VM contient également le **pool ZFS principal** (`tank`) qui gère les datasets médias, photos, appdata et sauvegardes.

---

## ⚙️ Spécifications techniques

| Élément | Détail |
|----------|--------|
| **Nom VM** | `vm-intranet` |
| **OS** | Debian 12 (Bookworm) |
| **Réseau Proxmox** | `vmbr0` (LAN / INTRANET) |
| **CPU / RAM** | 4 vCPU, 8–16 Go RAM |
| **Disque virtuel** | 60–100 Go SSD (OS + Docker), ZFS monté depuis hôte |
| **IP statique** | `192.168.1.10` (exemple) |
| **Pare-feu Proxmox** | Activé |
| **Snapshots** | Quotidiens (ZFS auto-snapshot) |
| **Sauvegardes** | Intégrales via Restic |

---

## 🌐 Services hébergés

| Service | Description | Port(s) | Docker / Natif |
|----------|--------------|----------|----------------|
| **Jellyfin** | Serveur multimédia (streaming local) | 8096 | Docker |
| **Immich (API + microservices)** | Gestion photos, synchronisation mobile | 2283, 3001 | Docker |
| **Postgres** | Base de données Immich | 5432 (local only) | Docker |
| **Prometheus** | Collecte métriques système & conteneurs | 9090 | Docker |
| **Grafana** | Visualisation des métriques | 3000 | Docker |
| **Restic** | Sauvegarde incrémentale chiffrée | — | Natif |
| **node_exporter / smartctl_exporter** | Export métriques système | 9100+ | Docker |

> Aucun service de cette VM n’est accessible directement depuis Internet.  
> Tous les accès passent par la **VM-EXTRANET (NPM/OpenVPN)**.

---

## 🗂️ Volumes & stockage ZFS

| Dataset | Point de montage | Usage | Fréquence snapshot |
|----------|------------------|--------|---------------------|
| `tank/media` | `/mnt/tank/media` | Fichiers vidéos Jellyfin | Hebdomadaire |
| `tank/photos` | `/mnt/tank/photos` | Bibliothèque Immich | Hebdomadaire |
| `tank/appdata` | `/mnt/tank/appdata` | Données Docker & bases | Quotidienne |
| `tank/backups` | `/mnt/tank/backups` | Sauvegardes Restic | Quotidienne |

### Options ZFS appliquées
```bash
zfs set compression=lz4 tank
zfs set atime=off tank
zfs set recordsize=1M tank/media
````

---

## 🔒 Sécurité & réseau

### Connexions autorisées (via Proxmox Firewall)

| Source → Cible          | Ports                                                                           | Description                 |
| ----------------------- | ------------------------------------------------------------------------------- | --------------------------- |
| **EXTRANET → INTRANET** | 8096 (Jellyfin), 2283/3001 (Immich), 9090 (metrics), 3000 (Grafana - restreint) | Flux proxy & supervision    |
| **INTRANET → EXTRANET** | 443 (ACME), 9100 (scrape node_exporter EXTRANET)                                | Sortants sécurisés          |
| **INTRANET ↔ Internet** | Sortants seulement                                                              | Mises à jour, images Docker |

### UFW (exemple)

```bash
# Configuration UFW - VM-INTRANET
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.10.0.10 to any port 8096 proto tcp comment 'Jellyfin (via NPM)'
sudo ufw allow from 10.10.0.10 to any port 2283 proto tcp comment 'Immich API (via NPM)'
sudo ufw allow from 10.10.0.10 to any port 3001 proto tcp comment 'Immich microservices (via NPM)'
sudo ufw allow from 10.10.0.10 to any port 9090 proto tcp comment 'Prometheus metrics'
sudo ufw enable
```

---

## 🔁 Sauvegardes (Restic)

| Élément                                 | Fréquence    | Détail                                |
| --------------------------------------- | ------------ | ------------------------------------- |
| **Appdata Docker**                      | Quotidienne  | `/mnt/tank/appdata`                   |
| **Bases de données (Postgres)**         | Quotidienne  | Dump avant backup Restic              |
| **Médias & Photos**                     | Hebdomadaire | `/mnt/tank/media`, `/mnt/tank/photos` |
| **Configs système**                     | Hebdomadaire | `/etc`, `/var/lib/docker/volumes`     |
| **Réplication Restic externe (option)** | Mensuelle    | Vers NAS ou disque USB                |

### Commandes principales

```bash
restic backup /mnt/tank/appdata /mnt/tank/media /mnt/tank/photos /etc
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3
restic check
```

---

## 📊 Monitoring

* **Prometheus** collecte :

  * `node_exporter` (INTRANET + EXTRANET)
  * `cadvisor` (conteneurs Docker)
  * `smartctl_exporter` (état disques ZFS)
  * `restic_exporter` (état sauvegardes)
* **Grafana** : accessible en LAN ou via NPM (accès restreint).
* **Alertes** : alertmanager (optionnel) → Discord/mail.
* Dashboards exportés dans `/configs/grafana/dashboards/`.

---

## 🧰 Maintenance

| Tâche                 | Fréquence | Commande / Outil               |
| --------------------- | --------- | ------------------------------ |
| Mises à jour système  | Hebdo     | `apt update && apt upgrade -y` |
| MàJ conteneurs Docker | Auto      | Watchtower                     |
| Vérification ZFS      | Mensuelle | `zpool scrub tank`             |
| Vérification Restic   | Mensuelle | `restic check`                 |
| Vérification disques  | Mensuelle | `smartctl -a /dev/sdX`         |
| Logs et alertes       | Continu   | Prometheus + Grafana           |

---

## 🔐 Accès & administration

| Élément                | Détail                                        |
| ---------------------- | --------------------------------------------- |
| **SSH**                | Clés publiques uniquement (pas de root login) |
| **Accès Web**          | Aucun direct (via NPM)                        |
| **Utilisateurs admin** | `media-admin` (sudo limité)                   |
| **Pare-feu**           | UFW + Proxmox Firewall actifs                 |
| **VPN**                | Accès via OpenVPN (tunnel EXTRANET)           |

---

## 🧠 Notes techniques

* Tous les conteneurs Docker sont dans le **réseau `intranet-net`** (bridge isolé).
* Les datasets ZFS sont montés automatiquement via `/etc/fstab`.
* Les métriques sont scrappées uniquement depuis `192.168.x.x` (INTRANET).
* Les exports Restic et logs Prometheus sont sauvegardés quotidiennement.

---

## 🔮 Roadmap d’évolution

* [ ] Ajouter automatisation des snapshots ZFS avec `zfs-auto-snapshot`.
* [ ] Centraliser les logs via Promtail + Loki.
* [ ] Ajouter dashboard Restic dans Grafana.
* [ ] Étudier chiffrement ZFS natif sur datasets sensibles (`appdata`, `backups`).

---

🗓️ **Journal de bord – 02/11/2025**
Création de la VM-INTRANET documentée.
Contient les services Jellyfin, Immich, Postgres, Prometheus, Grafana, Restic.
Flux entrants limités à la VM-EXTRANET.
Sauvegardes quotidiennes Restic et snapshots ZFS automatiques.

```

---

