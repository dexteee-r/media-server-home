# ADR-008 — Segmentation réseau & multi-VM (Intranet / Extranet)

## 📘 Contexte

Le projet **media-server-home** visait initialement à faire tourner tous les services (NPM, Jellyfin, Immich, etc.) dans une seule VM “Services”.  
Cependant, cette approche concentrait à la fois les services exposés (reverse proxy, VPN) et les services internes (bases de données, stockage médias), ce qui augmentait la surface d’attaque et complexifiait la maintenance.

Pour améliorer la **sécurité**, la **cloisonnement réseau** et la **résilience**, il est décidé de **séparer l’infrastructure en deux machines virtuelles distinctes** :
- **VM-EXTRANET (DMZ)** : pour les services exposés ou frontaux.  
- **VM-INTRANET (LAN)** : pour les services internes et les données sensibles.

---

## ⚙️ Problème à résoudre

Comment isoler efficacement les composants exposés (web, VPN) des services critiques (médias, bases de données, sauvegardes), tout en conservant :
- une communication fluide entre les deux VMs,
- des sauvegardes simples,
- et une supervision centralisée.

---

## 🧩 Options étudiées

| Option | Description | Avantages | Inconvénients |
|--------|--------------|------------|----------------|
| **Monolithique (1 VM)** | Tous les services dans une seule VM. | Simple à déployer, peu de ressources. | Surface d’attaque large, sécurité faible, rétablissement plus long. |
| **Bimachine (Intranet / Extranet)** | Deux VMs séparées selon le type d’exposition. | Cloisonnement fort, sécurité accrue, sauvegardes ciblées. | Configuration réseau plus complexe. |
| **Trimachine (Intranet / Extranet / Monitoring)** | Ajout d’une VM “Ops” dédiée à la supervision. | Séparation maximale. | Plus de complexité et de maintenance. |

---

## ✅ Décision finale

> **Adopté : architecture bimachine (Intranet / Extranet).**

### Répartition :
- **VM-EXTRANET** :  
  - Reverse Proxy (Nginx Proxy Manager)  
  - VPN (OpenVPN)  
  - Exporters ou services à exposition publique limitée  
- **VM-INTRANET** :  
  - Jellyfin, Immich, Postgres, Prometheus, Grafana, Restic  
  - Stockage ZFS (`/mnt/tank/...`)  
  - Aucune exposition directe

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Sécurité** | Surface d’attaque réduite. Les données sensibles ne sont jamais exposées directement. |
| **Réseau** | Création de deux bridges Proxmox : `vmbr0` (LAN) et `vmbr1` (DMZ). Routage et pare-feux configurés entre VMs. |
| **Sauvegardes** | Référentiels distincts : un par VM. L’ordre de restauration priorise l’INTRANET. |
| **Monitoring** | Prometheus dans l’INTRANET scrape les exporters du DMZ via ports ouverts spécifiquement. |
| **Maintenance** | Possibilité de redéployer la VM-EXTRANET indépendamment en cas de corruption ou fail. |

---

## 🔐 Flux autorisés (matrice simplifiée)

| Source → Cible | Ports | Motif |
|----------------|-------|-------|
| **Clients LAN → EXTRANET** | 443 (HTTPS), 1194/UDP (VPN) | Accès frontal |
| **EXTRANET → INTRANET** | 8096 (Jellyfin), 2283/3001 (Immich), 9090 (Prometheus metrics) | Routage proxy + monitoring |
| **INTRANET → EXTRANET** | 443 (Let’s Encrypt ACME), 25/587 (notifications) | Sortants contrôlés |
| **INTRANET ↔ Internet** | Sortants uniquement (apt, images Docker) | Pas d’accès entrant direct |

---

## 🧠 Impacts organisationnels

- Deux fiches VM dans `/infra/vm/` : `services-extranet.md` et `services-intranet.md`.  
- Deux contextes réseau documentés dans `/infra/proxmox/README.md`.  
- Pare-feu UFW + Proxmox Firewall activés et synchronisés.  
- Sauvegardes et snapshots distincts par VM.  
- Runbooks (`OPERATIONS.md`) mis à jour pour inclure la séquence de restauration multi-VM.

---

## 🔮 Actions suivantes

- [ ] Créer le bridge réseau `vmbr1` (DMZ).  
- [ ] Configurer UFW et Proxmox Firewall selon la matrice de flux.  
- [ ] Mettre à jour les documents `ARCHITECTURE.md`, `SECURITY.md` et `OPERATIONS.md`.  
- [ ] Rédiger ADR-009 (Placement des services).  

---

🗓️ **Journal de bord – 02/11/2025**  
- Décision : segmentation réseau en **2 VMs** (EXTRANET / INTRANET).  
- Objectif : isolation, sécurité accrue, simplification des backups et déploiements.  
- Étape suivante : définir le placement précis des services (ADR-008).
