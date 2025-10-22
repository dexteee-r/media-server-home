# ADR-002 — Choix de l’orchestration des services : **Docker Compose vs LXC**

## 📘 Contexte

Le projet **media-server-home** repose sur plusieurs services interdépendants :
- **Jellyfin** → streaming multimédia avec transcodage matériel (Intel QuickSync)  
- **Immich** → synchronisation et gestion des photos (Postgres + Redis)  
- **Traefik** → reverse proxy / HTTPS / routage interne  
- **Prometheus & Grafana** → monitoring et alerting  
- **Restic / Borg** → sauvegardes chiffrées  
- **Tailscale / WireGuard** → accès distant sécurisé  

Tous ces services doivent tourner au sein de la **VM “Services” (Ubuntu Server 24.04)** hébergée sur **Proxmox VE 8**.  
La question porte sur le **modèle d’orchestration** à adopter :  
- utiliser **Docker + Docker Compose**,  
- ou bien déployer chaque service dans un **conteneur LXC** séparé directement sous Proxmox.

---

## ⚙️ Problème à résoudre

Trouver la **méthode d’orchestration optimale** pour :
1. Gérer plusieurs services isolés mais interconnectés.  
2. Simplifier la maintenance (backup, logs, mises à jour).  
3. Garantir la compatibilité avec les stacks open-source modernes (Traefik, Immich, Prometheus).  
4. Permettre une évolution future vers LXC natif ou Kubernetes sans tout reconstruire.

---

## 🧩 Options étudiées

| Option | Description | Avantages | Inconvénients |
|--------|--------------|------------|----------------|
| **Docker Compose (dans VM Ubuntu)** | Tous les services s’exécutent dans des conteneurs Docker orchestrés par un `docker-compose.yml`. | - Standard DevOps répandu<br>- Portabilité totale (rebuild facile)<br>- Isolation réseau simplifiée<br>- Configuration versionnée (Git)<br>- Support natif plugins (Traefik, Watchtower, etc.) | - Légère surcouche par rapport à LXC natif<br>- Overhead mineur CPU/mémoire<br>- Requiert Docker Engine (daemon) |
| **LXC (Proxmox)** | Chaque service tourne dans un conteneur LXC isolé (Debian/Ubuntu minimal). | - Performances quasi natives<br>- Isolation système plus fine<br>- Utilise moins de RAM par service | - Maintenance plus lourde (MAJ par LXC)<br>- Pas de fichier unique d’orchestration<br>- Complexité réseau (ports, reverse-proxy)<br>- Moins portable entre environnements |
| **Mixte (Docker + quelques LXC)** | VM Docker pour la majorité, mais certains services lourds (ex: Immich ou DB) en LXC séparé. | - Permet isolation sélective<br>- Idéal pour tests ou sandbox | - Gestion hybride plus complexe<br>- Backups moins homogènes |

---

## 🧮 Critères de décision

| Critère | Pondération | Docker Compose | LXC | Mixte |
|----------|--------------|----------------|------|--------|
| **Facilité d’orchestration / redéploiement** | 5 | ✅ | ⚠️ | ⚠️ |
| **Maintenance / MàJ** | 5 | ✅ Watchtower / pull + up | ⚠️ Manuel | ⚠️ |
| **Performances** | 4 | ⚠️ Légère surcouche (~2–5 %) | ✅ Natif | ✅ |
| **Isolation / Sécurité** | 4 | ✅ Réseaux, namespaces, user mapping | ✅ Kernel namespaces | ⚠️ |
| **Compatibilité avec Traefik / Docker labels** | 5 | ✅ Native | ❌ Non applicable | ⚠️ |
| **Backups / Restore homogène** | 4 | ✅ Volumes + Restic/Borg | ⚠️ Snapshots LXC séparés | ⚠️ |
| **Portabilité (autres machines / cloud)** | 4 | ✅ Facile via Compose / Git | ❌ LXC local uniquement | ⚠️ |
| **Documentation / communauté** | 3 | ✅ Très vaste | ⚠️ Limitée | ⚠️ |
| **Évolutivité vers Kubernetes / Swarm** | 3 | ✅ Migration naturelle | ⚠️ Peu adaptée | ⚠️ |
| **Score total (/37)** | – | **35 / 37** | 28 / 37 | 30 / 37 |

---

## ✅ Décision finale

> **Adopté : Docker Compose comme orchestrateur principal dans la VM “Services” Ubuntu.**

### Justification

- Permet de regrouper tous les services dans un seul fichier versionné (`docker-compose.yml`).  
- Maintenance ultra-simple : `docker compose pull && docker compose up -d`.  
- Compatible avec **Traefik**, **Watchtower**, **Restic**, **Prometheus**, etc.  
- Isolation suffisante pour un usage domestique, tout en gardant la flexibilité DevOps.  
- Facilite le déploiement reproductible (Git clone + Makefile).  
- Préserve une option future : migration vers **LXC** ou **Kubernetes** si besoin d’optimisation.

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Structure du dépôt** | Le `docker-compose.yml` devient la référence centrale (versionné dans Git). |
| **Backups** | Sauvegardes cohérentes via `restic` ou `borg` sur les volumes `/mnt/appdata`. |
| **Monitoring** | Stack Prometheus / Grafana déployable comme service Docker supplémentaire. |
| **Réseau interne** | Utilisation d’un bridge Docker (ex: `traefik-net`) avec labels automatiques. |
| **Performance** | Impact minimal, acceptable pour une machine i5-6500 avec 8–16 GB RAM. |
| **Migration future** | Possibilité de migrer les conteneurs vers LXC avec Podman ou K3s. |

---

## 🔮 Actions suivantes

- [ ] Rédiger **ADR-003 : choix du reverse-proxy (Traefik vs Nginx PM)**.  
- [ ] Créer le squelette du `docker-compose.yml` minimal.  
- [ ] Définir les **volumes et mounts ZFS** (`/mnt/media`, `/mnt/appdata`, `/mnt/photos`).  
- [ ] Ajouter un **Makefile** pour les opérations (`up`, `down`, `logs`, `backup`).  
- [ ] Documenter la **VM “Services”** dans `/infra/vm/services-ubuntu.md`.

---

🗓️ **Journal de bord – 22/10/2025**  
- Décision : utilisation de **Docker Compose** pour l’orchestration des services.  
- Raisons : standard DevOps, simplicité de maintenance, portabilité, compatibilité Traefik.  
- Étape suivante : comparaison des reverse-proxy (ADR-003) et rédaction du `docker-compose.yml` minimal.
