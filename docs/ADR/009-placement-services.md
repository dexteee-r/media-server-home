# ADR-008 — Placement des services par VM

## 📘 Contexte

Suite à la segmentation réseau validée dans l’ADR-007, il est nécessaire de préciser **la répartition exacte des services** entre la VM-EXTRANET (DMZ) et la VM-INTRANET (LAN).  
L’objectif est de garantir que les services exposés restent isolés des données internes, tout en assurant la communication nécessaire via des flux sécurisés.

---

## 🧩 Répartition des services

| Catégorie | Service | VM | Justification |
|------------|----------|----|----------------|
| **Réseau / Accès** | OpenVPN | EXTRANET | Fournir un accès distant chiffré sans exposer les autres services. |
| **Proxy / HTTPS** | Nginx Proxy Manager (NPM) | EXTRANET | Point d’entrée HTTPS unique pour les utilisateurs. |
| **Streaming** | Jellyfin | INTRANET | Accès via proxy uniquement, isolation du stockage multimédia. |
| **Photos / API** | Immich (API + microservices) | INTRANET | Données sensibles (photos, comptes). |
| **Base de données** | Postgres (Immich) | INTRANET | Maintien de la cohérence et de la confidentialité. |
| **Sauvegarde** | Restic | INTRANET | Sauvegardes locales + distantes, accès au ZFS. |
| **Monitoring** | Prometheus + Grafana | INTRANET | Centralisation des métriques (scrape des exporters EXTRANET). |
| **Exporters** | node_exporter, smartctl_exporter | INTRANET + EXTRANET | Export des métriques systèmes pour Grafana. |

---

## ✅ Décision finale

> Adopter une **séparation stricte des rôles** entre les deux VMs :  
> - **EXTRANET** = accès réseau, proxy, VPN  
> - **INTRANET** = données, services applicatifs, monitoring, backups  

Cette répartition favorise :
- la **défense en profondeur** (isolation logique des données),  
- la **facilité de restauration** (VM DMZ reconstruisible indépendamment),  
- la **stabilité** (les services internes non impactés par un crash du proxy).

---

## 🔁 Conséquences & impacts

| Domaine | Impact |
|----------|--------|
| **Docker Compose** | Deux fichiers ou deux profils : `compose.extranet.yml` et `compose.intranet.yml`. |
| **Backups** | Deux dépôts Restic distincts, restaurables séparément. |
| **Monitoring** | Prometheus (INTRANET) scrute EXTRANET via ports 9100/metrics. |
| **CI/CD** | Deux pipelines indépendants possibles (par VM). |
| **Mises à jour** | Watchtower actif sur les deux VMs, configurations indépendantes. |

---

## 🔒 Sécurité (complément à SECURITY.md)

- Aucun volume ZFS n’est monté sur EXTRANET.  
- Les accès EXTRANET → INTRANET sont limités aux ports applicatifs (HTTPS ou API).  
- Tous les dumps, logs et sauvegardes restent confinés dans l’INTRANET.  
- Surveillance et alertes centralisées côté INTRANET.

---

## 🔮 Actions suivantes

- [ ] Adapter `ARCHITECTURE.md` pour refléter la séparation VM.  
- [ ] Mettre à jour `SECURITY.md` avec la matrice de flux complète.  
- [ ] Créer les fiches `/infra/vm/services-extranet.md` et `/infra/vm/services-intranet.md`.  
- [ ] Préparer les fichiers `docker-compose.extranet.yml` et `docker-compose.intranet.yml`.  
- [ ] Définir les jobs Watchtower distincts pour chaque VM.

---

🗓️ **Journal de bord – 02/11/2025**  
- Décision : répartition des services entre VM-EXTRANET et VM-INTRANET.  
- Objectif : durcissement de la sécurité et simplification de la maintenance.  
- Étape suivante : mise à jour de la documentation d’architecture et création des fiches VM.
