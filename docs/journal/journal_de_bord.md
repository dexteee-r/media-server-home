# 🗓️ Journal de bord 

note de rappel pur plus tard : 
installer une VM tiny win11

**Date: 19/10/25 : lancement du projet :**

j'ai réaliser 2 prompt context, un pour GPT (pour la partie recherche et documentation) et l'autre pour CLAUDE (pour la partie code et dev) 

- comparatif Jellyfin / Plex / Emby 
	choix final : 
- Comparatif Immich / PhotoPrism / Nextcloud Photos → gestion photos.
	choix final : 

- Tableau TrueNAS / OpenMediaVault / MinIO.
	choix final : 



**Date: 21/10/2025**
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


**Date 22/10/2025**
Décisions:
  - ajout d'un hdd de 500go dans la machine
  - changment de ram initialement 8go mtn -> 16go 
  - ces composants proviennent d'autre machines plus utiliser, j'ai donc fait du recyclage.
  - crétation de l'arbo du projet a upload dans GitHub
  -  utilisation de **Docker Compose** pour l’orchestration des services.  
  - Raisons : standard DevOps, simplicité de maintenance, portabilité, compatibilité Traefik.  
  - Étape suivante : comparaison des reverse-proxy (ADR-003) et rédaction du `docker-compose.yml` minimal.


