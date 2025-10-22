# ADR-001 — Choix de l’hyperviseur : **Proxmox VE**

## 📘 Contexte

Le projet vise à déployer un **media-server domestique auto-hébergé**, capable de faire tourner plusieurs services (Jellyfin, Immich, Traefik, Prometheus/Grafana, etc.) au sein d’une infrastructure **modulaire et maintenable**.  
L’objectif est d’exécuter ces services dans des environnements isolés (VM ou conteneurs Docker) tout en maintenant une **bonne performance, sécurité et facilité d’administration**.

La machine hôte principale est un **Dell Optiplex 7040** :
- **CPU** : Intel Core i5-6500 (4 cœurs, 3.2 GHz, QuickSync)
- **RAM** : 8 Go DDR4 (évolutif → 16 Go)
- **Stockage** : SSD NVMe 256 Go + HDD secondaire prévu
- **GPU** : Intel HD 530 (compatible VAAPI / transcodage matériel)
- **Carte réseau** : Intel I219-LM Gigabit
- **Usage visé** : VM + Docker + expérimentations réseau / sandbox

## ⚙️ Problème à résoudre

Trouver un **hyperviseur** :
- compatible avec le matériel (Intel VT-x / VT-d),
- capable de gérer **plusieurs VM** et conteneurs,
- intégrant une interface web, des snapshots et un système de sauvegarde,
- open-source et maintenable à long terme,
- supportant le **GPU passthrough** pour le transcodage Jellyfin.

## 🧩 Options étudiées

| Option | Type | Avantages | Inconvénients |
|--------|------|------------|----------------|
| **VirtualBox** | Desktop hypervisor | Simple à utiliser, multi-OS, stable | Peu performant, pas adapté à un usage 24/7, pas d’administration web |
| **VMware ESXi Free** | Bare-metal | Fiable, bonne gestion VM | Version Free limitée (snapshots, API), non libre |
| **Hyper-V** | Intégré Windows | Bonne intégration Windows | Peu flexible, pas d’outils LXC/Docker, pas open-source |
| **Proxmox VE 8** | Bare-metal Debian + KVM / LXC | Open-source, web UI, snapshots, backups, GPU passthrough, gestion ZFS | Légère courbe d’apprentissage, pas dédié Windows |

## 🧮 Critères de décision

| Critère | Pondération | VirtualBox | ESXi | Hyper-V | **Proxmox VE** |
|----------|--------------|-------------|-------|----------|----------------|
| Open-source / gratuit | 5 | ✅ | ❌ | ❌ | ✅ |
| Stabilité 24/7 | 5 | ⚠️ | ✅ | ✅ | ✅ |
| Interface web / gestion centralisée | 4 | ❌ | ✅ | ⚠️ | ✅ |
| Support GPU passthrough / VT-d | 5 | ❌ | ✅ | ⚠️ | ✅ |
| Support LXC / Docker | 4 | ❌ | ❌ | ❌ | ✅ |
| Snapshots / sauvegardes | 5 | ⚠️ | ✅ | ⚠️ | ✅ |
| Communauté / support | 4 | ✅ | ⚠️ | ⚠️ | ✅ |
| Facilité d’intégration (ZFS, Backups, Traefik) | 4 | ❌ | ⚠️ | ⚠️ | ✅ |
| **Total** | **–** | **13** | **24** | **20** | **38 / 40** |

## ✅ Décision finale

> **Choix retenu : Proxmox VE 8** comme hyperviseur principal.

### Justification

- Basé sur **Debian**, libre et activement maintenu.  
- Permet de gérer **VM KVM** et **conteneurs LXC** via une **interface web intuitive**.  
- Compatible avec le **GPU Intel HD 530 (QuickSync)** pour transcodage matériel sous Jellyfin.  
- Supporte **ZFS / Btrfs**, snapshots, sauvegardes automatiques et restauration granulaire.  
- Très bon compromis entre **souplesse, performance et stabilité 24/7**.  
- Forte communauté et abondante documentation.

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Performance** | Légère perte CPU vs bare-metal, mais négligeable (≈ 3–5 %). |
| **Maintenance** | Interface web simplifie la gestion, backups et monitoring intégrés. |
| **Évolutivité** | Migration simple vers LXC ou clusters futurs. |
| **Sécurité** | Cloisonnement complet des services (VM / LXC), support VPN (Tailscale/WireGuard). |
| **Compatibilité GPU** | Accélération matérielle Jellyfin via VAAPI/QuickSync disponible. |
| **Documentation** | Première pierre de l’architecture documentaire (*ADR-001*). |

## 🔮 Prochaines actions

- [ ] Créer **VM “Services” Ubuntu Server 24.04 LTS** (2 vCPU / 4 Go RAM / 20 Go SSD).  
- [ ] Activer **IOMMU / VT-d** dans le BIOS (si non fait).  
- [ ] Configurer le **bridge réseau vmbr0** pour accès LAN.  
- [ ] Planifier **ADR-002** : choix du système de fichiers (ZFS vs Btrfs).  
- [ ] Rédiger la **fiche technique Jellyfin (architecture + ports + transcodage)**.

---

🗓️ **Journal de bord – 21/10/2025**  
- Décision : adoption de **Proxmox VE 8**.  
- Raisons : open-source, web UI, ZFS, LXC/Docker, passthrough GPU.  
- Étape suivante : création de la VM “Services” et documentation ADR-002.

