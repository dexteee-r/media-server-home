# 🗓️ Journal de bord 

note de rappel pur plus tard : 
installer une VM tiny win11

## **Date: 19/10/25 : lancement du projet :**

j'ai réaliser 2 prompt context, un pour GPT (pour la partie recherche et documentation) et l'autre pour CLAUDE (pour la partie code et dev) 

- comparatif Jellyfin / Plex / Emby 
	choix final : 
- Comparatif Immich / PhotoPrism / Nextcloud Photos → gestion photos.
	choix final : 

- Tableau TrueNAS / OpenMediaVault / MinIO.
	choix final : 



## **Date: 21/10/2025**
Décisions:
  - Architecture cible: Proxmox VE + VM “Services” Docker (Option A), migration possible vers LXC plus tard.

  - Stack initiale: Traefik, Jellyfin, Immich (+ Postgres), Prometheus/Grafana, Watchtower, Tailscale/WireGuard, Restic/Borg.

  - Stockage recommandé: ZFS (datasets media, photos, appdata, backups).
  Arguments clés:

  - Besoin VMs + Docker → Proxmox simplifie l’orchestration, snapshots et GPU passthrough.

  - Sécurité & simplicité: accès distant via VPN au départ, pas d’exposition publique.
  - À faire (prochaine session):

  - Rédiger ADR-001 (hyperviseur), tableau “services/ports/volumes”, définir stratégie de sauvegarde.
  - Questions/données attendues:

  - Spécs machine + tests rapides (CPU/GPU/RAM/disques/réseau) pour ajuster transcodage et ZFS.


## **Date 22/10/2025**
Décisions:
  - ajout d'un hdd de 500go dans la machine
  - changment de ram initialement 8go mtn -> 16go 
  - ces composants proviennent d'autre machines plus utiliser, j'ai donc fait du recyclage.
  - crétation de l'arbo du projet a upload dans GitHub
  -  utilisation de **Docker Compose** pour l’orchestration des services.  
  - Raisons : standard DevOps, simplicité de maintenance, portabilité, compatibilité Traefik.  
  - Étape suivante : comparaison des reverse-proxy (ADR-003) et rédaction du `docker-compose.yml` minimal.




## **Date : 26 et 27/10/2025**
Décisions prises :

- **Architecture globale** : Media-server domestique sur Proxmox VE avec VM Ubuntu + Docker Compose (Jellyfin + Immich + Traefik)
  
- **Hyperviseur** : Proxmox VE choisi pour virtualisation, gestion GPU passthrough et évolutivité future

- **Stockage** : Installation Proxmox sur SSD NVMe 256GB (Samsung MZVLW256), effacement complet de Windows 11, HDD réservé pour bibliothèques médias

- **Partitionnement** : 
  - Filesystem ext4
  - 30GB root Proxmox
  - 4GB swap
  - ~200GB pour VMs/containers
  - 16GB réserve système

- **Réseau** : Configuration IP statique 192.168.1.100/24, gateway 192.168.1.1, connexion Ethernet temporaire (WiFi à configurer post-installation)

- **BIOS** : Passage du mode SATA de RAID/RST vers AHCI pour détection du SSD NVMe par l'installateur Proxmox

- **GPU Passthrough** : 
  - Activation IOMMU Intel (intel_iommu=on iommu=pt dans GRUB)
  - Chargement modules VFIO (vfio, vfio_iommu_type1, vfio_pci, vfio_virqfd)
  - Blacklist driver i915 pour libérer Intel HD Graphics 530
  - ID GPU forcé vers VFIO-PCI (8086:1912)
  - Objectif : Transcodage hardware H.264/H.265 via QuickSync dans Jellyfin

- **Dépôts APT** : Désactivation repo enterprise, activation pve-no-subscription pour mises à jour gratuites

- **Matériel cible** :
  - Dell OptiPlex 7040
  - CPU Intel Core i5-6500 (4 cores @ 3.2GHz, Skylake)
  - GPU Intel HD Graphics 530 (QuickSync support)
  - RAM 8GB DDR4-2133
  - Santé système validée (aucune erreur matérielle)

Problèmes rencontrés et résolus :

- SSD non détecté initialement → Résolu via changement BIOS SATA en mode AHCI
- Driver i915 persistant malgré blacklist → Tentative de bind forcé VFIO-PCI en cours
- Erreur initramfs ESP sync → Non bloquant, boot fonctionnel malgré warning

Prochaines étapes :

- Validation GPU passthrough (vérification `vfio-pci` actif)
- Création VM Ubuntu 24.04 LTS avec GPU assigné
- Déploiement stack Docker (Jellyfin + Immich + PostgreSQL + Redis + Traefik)
- Configuration transcodage hardware QuickSync
- Scripts backup/restore automatisés
- Configuration WiFi permanente (post-Ethernet)


## Journal de bord – 02/11/2025

### 🔧 Mises à jour système & infrastructure
- Passage des VMs sous **Debian 13**.
- Installation de **Docker** et **UFW** sur les deux VMs.
- Configuration du **pare-feu UFW** sur chaque VM avec politiques par défaut (`deny incoming`, `allow outgoing`).
- **VPN** configuré : **OpenVPN** opérationnel sur la VM-EXTRANET.
- **Reverse Proxy** remplacé : **Nginx Proxy Manager** (remplace Traefik).

### 🌐 Réseau & DNS
- Achat du domaine **elmzn.be** chez **OVH Cloud**.
- Mise en place d’un **DNS dynamique** via **OVH + ddclient** sur Debian.
- Ajout du sous-domaine : `intranet.elmzn.be` pour le réseau interne (INTRANET).
- Tests d’accès HTTPS internes validés via NPM.

### 🧱 Architecture & sécurité
- Passage officiel en **multi-VM** :
  - **VM-EXTRANET** : Nginx Proxy Manager, OpenVPN, node_exporter, UFW + Fail2ban.
  - **VM-INTRANET** : Jellyfin, Immich, Postgres, Prometheus, Grafana, Restic.
- Objectifs :
  - Réduire la surface d’attaque.
  - Isoler les services internes et les données critiques.
  - Simplifier la restauration et les backups.
- Pare-feu Proxmox activé sur **Datacenter + VM + Node**.
- Segmentation documentée entre les réseaux **vmbr0 (LAN)** et **vmbr1 (DMZ)**.

### 📘 Documentation mise à jour
- **ARCHITECTURE.md** : schéma multi-VM ajouté, flux inter-VM précisés.
- **SECURITY.md** : Tailscale remplacé par OpenVPN, ajout de la DMZ et flux inter-VM.
- **OPERATIONS.md** : procédures séparées (INTRANET / EXTRANET), ordres de restauration.
- **infra/proxmox/** : ajout des bridges et firewall.
- **infra/vm/** : création de `services-extranet.md` et `services-intranet.md`.
- **ADR-005** et **ADR-006** : ajout des sections *multi-VM adaptation* et *multi-VM monitoring*.
- **ADR-007** et **ADR-008** : ajoutés pour documenter la segmentation réseau et le placement des services.

### 🗄️ Sauvegardes & supervision
- **Restic** configuré sur INTRANET (quotidien) et EXTRANET (hebdo).
- Snapshots ZFS automatiques activés sur le pool `tank`.
- Exporters installés : `node_exporter`, `smartctl_exporter`, `cadvisor`.
- Monitoring multi-VM opérationnel : Prometheus (INTRANET) scrape EXTRANET via port 9100.
- Dashboards Grafana mis à jour et versionnés dans `/configs/grafana/dashboards/`.

### 🧠 Synthèse
- **VM-INTRANET** documentée : héberge Jellyfin, Immich, Postgres, Prometheus, Grafana, Restic.  
  Flux entrants limités à EXTRANET. Sauvegardes quotidiennes.  
- **VM-EXTRANET** documentée : NPM, OpenVPN, node_exporter, UFW + Fail2ban.  
  Flux sortants restreints, aucune donnée critique stockée localement.  
  Sauvegardes hebdomadaires exportées vers INTRANET.

### 📌 Prochaines actions
- Mettre à jour les configurations DNS publiques et privées (A / CNAME).  
- Vérifier la restauration Restic par VM.  
- Créer le premier jeu de dashboards Grafana “Infrastructure Overview”.

---
###🎯 Objectif initial
Mettre en place **tous les services de l'INTRANET** pour le projet **Media Server Home**.


## ✅ Ce qu'on a accompli

### 1. **Compréhension de l'architecture ZFS** 🧠
- **Question clé :** Pourquoi créer les datasets ZFS sur l'hôte Proxmox ?
- **Réponse :** 
  - ZFS a besoin d'accès direct aux disques physiques
  - Snapshots centralisés
  - Partage entre VMs
  - Meilleures performances (ARC cache partagé)
  - Intégrité maximale (checksums, SMART)

---

### 2. **Création des pools ZFS** 💾

#### Pool HDD (tank-hdd) - 450 GB
```bash
✅ Créé sur /dev/sda (HDD 500 GB complet)
✅ Compression LZ4 activée
✅ Atime désactivé
✅ 4 datasets créés :
   - media (300 GB quota, recordsize=1M)
   - photos (150 GB quota)
   - backups (80 GB quota)
   - logs (20 GB quota)
```

#### Pool SSD (tank-ssd) - 15 GB
```bash
✅ Créé sur volume LVM /dev/pve/zfs-ssd
✅ Option safe choisie (15 GB au lieu de 120 GB)
✅ Pas de manipulation risquée du LVM
✅ 2 datasets créés :
   - appdata (10 GB quota)
   - postgres (5 GB quota)
```

**Pourquoi 15 GB suffit :**
- Appdata : configs Docker (~5 GB max)
- Postgres : base Immich (~2-3 GB pour démarrer)
- Données volumineuses (photos/vidéos) sur HDD

---

### 3. **Création des VMs** 🖥️

#### VM-EXTRANET (ID 101)
```yaml
IP: 192.168.1.111
RAM: 4 GB
CPU: 2 cores
Disque: 20 GB
OS: Debian 13 (Trixie)
Rôle: DMZ / Porte d'entrée Internet
```

#### VM-INTRANET (ID 100) - existait déjà
```yaml
IP: 192.168.1.101
RAM: 12 GB
CPU: 3 cores
Disque: 32 GB
OS: Debian 13 (Trixie)
Rôle: Services privés (Jellyfin, Immich, etc.)
```

**Décision stratégique :** Créer VM-EXTRANET **AVANT** le pool SSD pour éviter de manipuler LVM deux fois.

---

### 4. **Tentative de bind mounts** ⚠️

**Problème découvert :** Les bind mounts Proxmox (`mp0:`) ne fonctionnent que pour les **conteneurs LXC**, pas pour les **VMs QEMU/KVM**.

```bash
❌ Tentative : Éditer /etc/pve/qemu-server/100.conf
❌ Résultat : Montages n'apparaissent pas dans la VM
✅ Solution : Passer à NFS
```

---

### 5. **Configuration NFS** 🌐

#### Serveur NFS (Proxmox)
```bash
✅ Installation : nfs-kernel-server
✅ Configuration : /etc/exports
✅ 6 exports créés :
   - 5 pour VM-INTRANET (appdata, postgres, media, photos, backups)
   - 1 pour VM-EXTRANET (logs)
✅ Service actif et vérifié
```

#### Client NFS (VM-INTRANET)
```bash
✅ Installation : nfs-common
✅ 5 montages NFS configurés
✅ Ajout au /etc/fstab pour persistance
✅ Vérifié après reboot : tous les montages OK
```

#### Client NFS (VM-EXTRANET)
```bash
✅ Installation : nfs-common
✅ 1 montage NFS configuré (/mnt/logs)
✅ Ajout au /etc/fstab
✅ Vérifié après reboot : montage OK
```

---

## 📊 Architecture finale validée

```
╔═══════════════════════════════════════════════════════════════╗
║ PROXMOX VE 8.4 (192.168.1.100)                               ║
║                                                               ║
║ STOCKAGE ZFS                                                  ║
║ ├─ tank-ssd (15 GB) - SSD NVMe                              ║
║ │  ├─ appdata  (10 GB)  → NFS → VM-INTRANET                 ║
║ │  └─ postgres (5 GB)   → NFS → VM-INTRANET                 ║
║ └─ tank-hdd (450 GB) - HDD                                  ║
║    ├─ media    (300 GB) → NFS → VM-INTRANET                 ║
║    ├─ photos   (150 GB) → NFS → VM-INTRANET                 ║
║    ├─ backups  (80 GB)  → NFS → VM-INTRANET                 ║
║    └─ logs     (20 GB)  → NFS → VM-EXTRANET                 ║
║                                                               ║
║ VMS                                                           ║
║ ├─ VM-EXTRANET (192.168.1.111) - 4 GB RAM, 2 vCPU           ║
║ │  └─ /mnt/logs (NFS) ✅                                      ║
║ └─ VM-INTRANET (192.168.1.101) - 12 GB RAM, 3 vCPU          ║
║    ├─ /mnt/appdata  (NFS) ✅                                  ║
║    ├─ /mnt/postgres (NFS) ✅                                  ║
║    ├─ /mnt/media    (NFS) ✅                                  ║
║    ├─ /mnt/photos   (NFS) ✅                                  ║
║    └─ /mnt/backups  (NFS) ✅                                  ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 🎯 État actuel

```
✅ Infrastructure Proxmox opérationnelle
✅ Pools ZFS créés et optimisés
✅ 2 VMs créées et configurées
✅ NFS configuré et persistant
✅ Tous les montages testés et validés après reboot
✅ Docker déjà installé dans VM-INTRANET
```

---

## 🚀 Prochaines étapes : DÉPLOIEMENT DES SERVICES

### VM-INTRANET
```yaml
Services à déployer :
- Jellyfin (streaming vidéo/musique)
- Immich (gestion photos + app mobile)
- PostgreSQL (DB Immich)
- Redis (cache Immich)
- Prometheus (monitoring)
- Grafana (dashboards)
- node_exporter (métriques système)
```

### VM-EXTRANET
```yaml
Services à déployer :
- Nginx Proxy Manager (reverse proxy HTTPS)
- OpenVPN (VPN accès distant)
- ddclient (DNS dynamique OVH)
- Fail2ban (protection bruteforce)
- UFW (firewall)
- node_exporter (métriques système)
```

---

## 💡 Décisions techniques clés prises

| Décision | Choix | Raison |
|----------|-------|--------|
| **Ordre de création** | VMs → Pools ZFS | Éviter double manipulation LVM |
| **Taille pool SSD** | 15 GB (safe) | Pas de réduction LVM risquée |
| **Montage datasets** | NFS (pas bind mount) | Bind mounts = LXC only |
| **Persistance** | /etc/fstab | Montages auto après reboot |
| **Sécurité NFS** | no_root_squash | Accès complet depuis VMs |

---

## 📈 Temps estimé restant

```
✅ Infrastructure : 100% DONE
🔧 Déploiement services : ~1-2h
🔒 Sécurisation : ~30min
🧪 Tests & validation : ~30min
📝 Documentation finale : ~30min
```

---

## 🎉 Résumé en une phrase

**On a construit une infrastructure Proxmox + ZFS + NFS solide avec 2 VMs (EXTRANET + INTRANET), prête à accueillir tous les services Docker du Media Server !** 🚀


