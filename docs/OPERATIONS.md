
# ⚙️ Guide d’exploitation — *media-server-home*

## 📘 Contexte général

Ce document décrit l’ensemble des **procédures d’exploitation, maintenance et restauration** du projet **media-server-home**.  
L’infrastructure est composée de deux machines virtuelles distinctes sous **Proxmox VE 8** :

| VM | Rôle | OS | Réseau | Services principaux |
|----|------|----|----------|----------------------|
| **VM-EXTRANET** | Accès externe / DMZ | Debian 12 | `vmbr1` (DMZ) | Nginx Proxy Manager, OpenVPN, node_exporter |
| **VM-INTRANET** | Backends & données | Debian 12 | `vmbr0` (LAN) | Jellyfin, Immich, Postgres, Prometheus, Grafana, Restic |

---

## 🧱 1. Structure générale

```

Proxmox VE (hôte)
├── vm-extranet (DMZ)
│     ├── NPM (80/443)
│     ├── OpenVPN (1194/UDP)
│     └── node_exporter (9100)
│
└── vm-intranet (LAN)
├── Jellyfin (8096)
├── Immich (2283/3001)
├── Postgres (5432)
├── Prometheus (9090)
├── Grafana (3000)
└── Restic + ZFS backups

````

---

## 🧰 2. Procédures générales

### 🧩 Démarrage complet du système
1. Démarrer l’hôte **Proxmox VE**.
2. Lancer les VMs dans l’ordre :
   - **VM-EXTRANET** → permet accès VPN / HTTPS.  
   - **VM-INTRANET** → services internes et backends.
3. Vérifier les connexions :
   ```
   ping 10.10.0.10    # EXTRANET
   ping 192.168.1.10  # INTRANET
    ```

4. Vérifier le VPN :

   ```
   sudo systemctl status openvpn
   ```

---

## 🌐 3. VM-EXTRANET — Exploitation & maintenance

### ⚙️ Démarrage des services Docker

    ```bash 
    cd /opt/extranet/
    docker compose up -d
    docker ps
    ```

### 🔒 Pare-feu UFW (exemple)

    ```
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 1194/udp
    sudo ufw allow from 192.168.1.0/24 to any port 9100 proto tcp
    sudo ufw enable
    ```

### 🧱 Maintenance régulière

| Tâche                 | Fréquence   | Commande                           |
| --------------------- | ----------- | ---------------------------------- |
| MàJ système           | Hebdo       | `apt update && apt upgrade -y`     |
| MàJ conteneurs        | Auto        | via Watchtower                     |
| Vérif certificats NPM | Hebdo       | Interface web                      |
| Vérif service VPN     | Hebdo       | `systemctl status openvpn`         |
| Logs VPN & NPM        | Quotidienne | `/mnt/tank/appdata/logs/extranet/` |

### 💾 Sauvegarde (configs uniquement)

| Élément              | Méthode                      | Fréquence | Cible                           |
| -------------------- | ---------------------------- | --------- | ------------------------------- |
| NPM configs + SSL    | `rsync` via SSH              | Hebdo     | `/mnt/tank/backups/npm-config/` |
| OpenVPN keys         | Script export + `scp`        | Mensuel   | `/mnt/tank/backups/openvpn/`    |
| Docker compose files | Git / backup Restic INTRANET | Hebdo     | `/mnt/tank/backups/configs/`    |

### 🔁 Restauration (extranet)

1. Recréer VM Debian 12.
2. Installer Docker + Compose + NPM.
3. Restaurer :

   ```bash
   rsync -av /mnt/tank/backups/npm-config/ /opt/extranet/npm/
   scp /mnt/tank/backups/openvpn/* /etc/openvpn/
   ```
4. Redémarrer :

   ```bash
   docker compose up -d
   systemctl restart openvpn
   ```

---

## 🗄️ 4. VM-INTRANET — Exploitation & maintenance

### ⚙️ Démarrage des services Docker

    ```bash
    cd /opt/intranet/
    docker compose up -d
    docker ps
    ```

### 🔍 Vérification du stockage ZFS

    ```bash
    zpool status
    zfs list
    ```

### 🔄 Snapshots automatiques

Gérés via `zfs-auto-snapshot` :

    ```bash
    sudo apt install zfs-auto-snapshot
    zfs list -t snapshot
    ```

### 💾 Sauvegardes Restic

| Type              | Commande                                                        | Fréquence    |
| ----------------- | --------------------------------------------------------------- | ------------ |
| Appdata + configs | `restic backup /mnt/tank/appdata`                               | Quotidienne  |
| Bases de données  | `pg_dumpall > /mnt/tank/backups/db.sql`                         | Quotidienne  |
| Médias / photos   | `restic backup /mnt/tank/media /mnt/tank/photos`                | Hebdomadaire |
| Vérification      | `restic check`                                                  | Mensuelle    |
| Rotation          | `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 3` | Mensuelle    |

### 🔁 Restauration (intranet)

1. Restauration via Restic :

   ```bash
   restic restore latest --target /mnt/tank/restore-test/
   ```
2. Recréation conteneurs :

   ```bash
   docker compose down && docker compose up -d
   ```
3. Validation ZFS :

   ```bash
   zpool scrub tank
   ```

---

## 📊 5. Supervision et alerting

### Prometheus

* Conteneur tournant sur INTRANET (`:9090`)
* Scrape :

  * `node_exporter` (INTRANET & EXTRANET)
  * `cadvisor`
  * `smartctl_exporter`
  * `restic_exporter`

### Grafana

* Conteneur sur INTRANET (`:3000`)
* Dashboards :

  * System overview
  * Docker / containers health
  * Restic backup status
  * ZFS usage & disk SMART

### Alertes (option)

* Alertmanager → envoi Discord / mail si :

  * échec de sauvegarde Restic
  * pool ZFS dégradé
  * conteneur down

---

## 🧠 6. Mises à jour & tâches planifiées

| Composant               | VM       | Fréquence | Méthode            |
| ----------------------- | -------- | --------- | ------------------ |
| OS Debian               | les 2    | Hebdo     | `apt upgrade -y`   |
| Docker images           | les 2    | Auto      | Watchtower         |
| ZFS scrub               | INTRANET | Mensuel   | `zpool scrub tank` |
| Restic check            | INTRANET | Mensuel   | `restic check`     |
| VPN cert rotation       | EXTRANET | Mensuel   | Script clé         |
| Tests de restauration   | INTRANET | Mensuel   | Dataset test       |
| Vérif certificats HTTPS | EXTRANET | Hebdo     | Interface NPM      |

---

## 🔁 7. Procédure de restauration complète (désastre)

### Étape 1️⃣ — Restaurer EXTRANET (accès)

1. Recréer VM Debian.
2. Réinstaller Docker + OpenVPN.
3. Restaurer configs NPM + OpenVPN keys.
4. Vérifier accès HTTPS / VPN.

### Étape 2️⃣ — Restaurer INTRANET (services)

1. Monter ZFS ou restaurer snapshots.
2. Restaurer Restic :

   ```bash
   restic restore latest --target /mnt/tank/
   ```
3. Restaurer conteneurs Docker :

   ```bash
   docker compose up -d
   ```
4. Vérifier services Jellyfin / Immich / Grafana.

### Étape 3️⃣ — Vérification

* Tester streaming Jellyfin (LAN)
* Vérifier dashboard Grafana
* Vérifier logs backup (`restic check`)

---

## 🧾 8. Table de référence des chemins

| Élément            | VM       | Chemin                          |
| ------------------ | -------- | ------------------------------- |
| Docker configs     | EXTRANET | `/opt/extranet/`                |
| Docker configs     | INTRANET | `/opt/intranet/`                |
| ZFS datasets       | INTRANET | `/mnt/tank/...`                 |
| Backups Restic     | INTRANET | `/mnt/tank/backups/restic-repo` |
| OpenVPN keys       | EXTRANET | `/etc/openvpn/keys/`            |
| NPM data           | EXTRANET | `/mnt/tank/appdata/npm`         |
| Grafana dashboards | INTRANET | `/configs/grafana/dashboards/`  |

---

## 🧭 9. Bonnes pratiques opérationnelles

✅ Tester les restaurations mensuellement.
✅ Garder les deux VMs à jour.
✅ Scrub ZFS chaque mois.
✅ Sauvegarder les clés VPN hors site.
✅ Ne jamais exposer Jellyfin/Immich directement.
✅ Vérifier la taille et la santé du pool ZFS avant chaque mise à jour majeure.

---

🗓️ **Journal de bord – 02/11/2025**

* Révision complète du guide d’exploitation (`OPERATIONS.md`).
* Séparation claire des procédures EXTRANET / INTRANET.
* Ajout des runbooks de sauvegarde, MAJ, et restauration multi-VM.
* Vérification de cohérence avec ADR-007/008 et SECURITY.md.

