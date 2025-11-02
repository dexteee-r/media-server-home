# 🖧 Configuration Proxmox VE — *media-server-home*

## 📘 Contexte général

L’hyperviseur **Proxmox VE 8** héberge les deux VMs principales du projet **media-server-home** :

| VM | Rôle | OS | Réseau | Services principaux |
|----|------|----|----------|----------------------|
| **VM-EXTRANET** | DMZ / Accès externe | Debian 12 | `vmbr1` (DMZ) | Nginx Proxy Manager, OpenVPN |
| **VM-INTRANET** | Données & backends | Debian 12 | `vmbr0` (LAN) | Jellyfin, Immich, Postgres, Grafana, Prometheus, Restic |

Le but de cette configuration est de **séparer physiquement les flux réseau** entre :
- la **zone exposée (EXTRANET)** ;
- la **zone privée (INTRANET)**.

---

## 🧱 1. Schéma d’ensemble

```

```
         +-------------------------------+
         |       Proxmox VE 8 Host       |
         |-------------------------------|
         | - ZFS (pool: tank)            |
         | - Firewall (enabled)          |
         | - Bridges réseau :            |
         |   • vmbr0 → LAN / INTRANET    |
         |   • vmbr1 → DMZ / EXTRANET    |
         +-------------------------------+
                 |               |
        +--------+--------+  +---+---------+
        |  VM-INTRANET    |  |  VM-EXTRANET |
        |  (192.168.1.10) |  |  (10.10.0.10)|
        +-----------------+  +--------------+
                ^                   |
                | (flux contrôlés)  |
                +-------------------+
```

````

---

## ⚙️ 2. Configuration réseau (bridges)

### Fichier : `/etc/network/interfaces`

```bash
auto lo
iface lo inet loopback

# LAN (INTRANET)
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.2/24
    gateway 192.168.1.1
    bridge-ports enp3s0
    bridge-stp off
    bridge-fd 0
    comment "Bridge LAN - INTRANET"

# DMZ (EXTRANET)
auto vmbr1
iface vmbr1 inet static
    address 10.10.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    comment "Bridge DMZ - EXTRANET"
````

> 💡 `vmbr1` n’est pas relié physiquement : il sert de réseau interne isolé pour les services exposés.

---

## 🧩 3. Configuration des VMs

| VM                    | Bridge utilisé | IP           | Accès autorisé                 |
| --------------------- | -------------- | ------------ | ------------------------------ |
| `vm-intranet`         | `vmbr0`        | 192.168.1.10 | LAN uniquement                 |
| `vm-extranet`         | `vmbr1`        | 10.10.0.10   | HTTPS (80/443), VPN (1194/UDP) |
| `prometheus` (option) | `vmbr0`        | —            | Scrape depuis INTRANET         |

### Commandes de vérification

```bash
qm list           # Liste des VMs
ip addr show      # Vérifier les interfaces sur l’hôte
ping 192.168.1.10 # Tester VM-INTRANET
ping 10.10.0.10   # Tester VM-EXTRANET
```

---

## 🔥 4. Pare-feu Proxmox

### Activation

1. **Datacenter → Firewall → Enabled**
2. **Node (hôte) → Firewall → Enabled**
3. **Chaque VM → Firewall → Enabled**

> Vérifie que le service est actif :

```bash
pve-firewall status
```

---

## 🧱 5. Règles de firewall (niveau VM)

### 🔹 VM-EXTRANET

| Direction | Action | Port(s)  | Source         | Description          |
| --------- | ------ | -------- | -------------- | -------------------- |
| IN        | ACCEPT | 80, 443  | LAN / Internet | Accès HTTPS (NPM)    |
| IN        | ACCEPT | 1194/UDP | Internet       | VPN OpenVPN          |
| IN        | ACCEPT | 9100     | 192.168.1.10   | Prometheus metrics   |
| IN        | DROP   | *        | *              | Bloque tout le reste |

### 🔹 VM-INTRANET

| Direction | Action | Port(s)          | Source                 | Description                   |
| --------- | ------ | ---------------- | ---------------------- | ----------------------------- |
| IN        | ACCEPT | 8096, 2283, 3001 | 10.10.0.10             | Jellyfin & Immich (via proxy) |
| IN        | ACCEPT | 9090             | 10.10.0.10             | Prometheus metrics            |
| IN        | ACCEPT | 3000             | 10.10.0.10 (optionnel) | Grafana (si exposé via NPM)   |
| IN        | DROP   | *                | *                      | Bloque tout le reste          |

---

## 🔒 6. Sécurité de l’hyperviseur

| Élément                  | Mesure                                                         |
| ------------------------ | -------------------------------------------------------------- |
| **SSH**                  | Désactivé pour root ; accès via utilisateur Proxmox spécifique |
| **Proxmox Firewall**     | Activé sur tous les niveaux                                    |
| **Sauvegardes Proxmox**  | Stockées sur disque local ou NAS (ZFS dataset dédié)           |
| **Mises à jour**         | `apt update && apt upgrade -y` chaque semaine                  |
| **Utilisateurs Proxmox** | Comptes séparés par rôle (`admin`, `backup`, `readonly`)       |
| **Sauvegardes VMs**      | Planifiées via `vzdump` ou Proxmox Backup Server               |
| **Monitoring**           | node_exporter sur chaque VM (scrapé par Prometheus)            |

---

## 💾 7. Sauvegardes au niveau hyperviseur

### Sauvegarde VM complète

```bash
vzdump <vmid> --compress zstd --storage local-zfs --mode snapshot
```

### Sauvegarde automatisée (crontab)

```bash
# Sauvegarde EXTRANET chaque jour à 3h
0 3 * * * vzdump 101 --compress zstd --storage local-zfs --mode snapshot --quiet 1

# Sauvegarde INTRANET chaque nuit à 4h
0 4 * * * vzdump 102 --compress zstd --storage local-zfs --mode snapshot --quiet 1
```

---

## 🧠 8. Monitoring de l’hôte Proxmox

* `pveproxy` et `pvedaemon` surveillés via Prometheus node_exporter.
* Les logs système (`/var/log/syslog`, `/var/log/pve/*`) sont envoyés vers la VM-INTRANET pour agrégation.
* Commandes utiles :

  ```bash
  pveperf             # Performance I/O CPU/Memory
  zpool status        # Santé du pool ZFS
  df -h / zfs list    # Vérification espace disque
  systemctl status pve* # Vérification services Proxmox
  ```

---

## 🧾 9. Notes pratiques

* Le **réseau DMZ (`vmbr1`)** ne doit **jamais accéder directement à Internet** sans passer par le proxy ou VPN.
* L’**INTRANET (`vmbr0`)** ne reçoit **aucun flux entrant** sauf depuis la VM-EXTRANET.
* Toujours **sauvegarder la configuration réseau** avant modification :

  ```bash
  cp /etc/network/interfaces /etc/network/interfaces.backup
  ```
* Les **firewalls Proxmox et UFW** sont complémentaires :

  * Proxmox filtre entre VMs et réseau physique.
  * UFW protège à l’intérieur de chaque VM.

---

🗓️ **Journal de bord — 02/11/2025**

* Mise à jour complète du guide d’infrastructure Proxmox.
* Bridges `vmbr0` (LAN) et `vmbr1` (DMZ) créés.
* Firewall Proxmox activé aux 3 niveaux (Datacenter, Node, VM).
* Documentation des règles EXTRANET / INTRANET.
* Procédures de sauvegarde et monitoring ajoutées.

