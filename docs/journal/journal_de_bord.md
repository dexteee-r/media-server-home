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

