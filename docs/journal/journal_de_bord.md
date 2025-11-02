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
