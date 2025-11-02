# ADR-005 — Choix de la stratégie de sauvegarde : **Restic vs BorgBackup**

## 📘 Contexte

Le projet **media-server-home** utilise **Proxmox VE** comme hyperviseur et **ZFS** comme système de fichiers (pool `tank` avec datasets `media`, `photos`, `appdata`, `backups`).  
La sauvegarde est un pilier essentiel du projet pour :
- éviter la perte de données en cas de panne disque, erreur humaine ou corruption ;
- assurer la restauration rapide des services Docker (Jellyfin, Immich, etc.) ;
- conserver un historique (snapshots + sauvegardes externalisées).

Les besoins de sauvegarde sont multiples :
1. **Sauvegardes locales** sur un disque dédié (`/mnt/tank/backups`).  
2. **Sauvegardes externes** (disque USB ou NAS).  
3. **Sauvegardes déportées** (cloud chiffré optionnel).  
4. **Tests périodiques de restauration.**

Deux outils open-source majeurs sont envisagés : **Restic** et **BorgBackup (Borg)**.

---

## ⚙️ Problème à résoudre

Choisir une solution de **sauvegarde incrémentale, chiffrée et automatisable**, adaptée à :
- un environnement Docker (volumes, bases de données, configurations) ;
- ZFS (snapshots et montages) ;
- la contrainte d’un serveur domestique (RAM limitée, stockage local).

---

## 🧩 Options étudiées

| Outil | Avantages | Inconvénients |
|--------|------------|----------------|
| **Restic** | - 100 % Go → binaire statique, aucune dépendance.<br>- Sauvegarde incrémentale dédupliquée et **chiffrée** (AES-256).<br>- Support de multiples backends : local, SFTP, SMB, rclone, cloud.<br>- Commandes simples (`restic backup`, `restic restore`).<br>- Bonne intégration dans scripts Bash et Docker. | - Moins efficace que Borg pour très grands ensembles non compressibles.<br>- Pas de compression native. |
| **BorgBackup** | - Très haute déduplication + compression intégrée (zlib/lz4).<br>- Vérification d’intégrité puissante (`borg check`). | - Dépendances Python.<br>- Moins compatible multi-backend.<br>- Moins portable. |

---

## 🧮 Critères de décision

| Critère | Pondération | Restic | BorgBackup |
|----------|--------------|--------|-------------|
| **Chiffrement intégré** | 5 | ✅ AES-256 natif | ✅ |
| **Déduplication efficace** | 4 | ✅ Bonne | ✅ Excellente |
| **Compression** | 3 | ⚠️ Non native | ✅ Intégrée |
| **Support multi-destination (SFTP / Cloud)** | 5 | ✅ Large | ⚠️ Limité |
| **Intégration Docker / scripts** | 4 | ✅ Simple (`restic` CLI) | ⚠️ Plus complexe |
| **Performances globales** | 4 | ✅ Très bonnes | ✅ Excellentes |
| **Maintenance / dépendances** | 3 | ✅ Binaire unique | ⚠️ Python requis |
| **Restauration sélective** | 3 | ✅ Possible par chemin | ✅ Possible |
| **Vérification d’intégrité** | 3 | ✅ `restic check` | ✅ `borg check` |
| **Score total (/34)** | — | **31 / 34** | **29 / 34** |

---

## ✅ Décision finale

> **Adopté : Restic** comme outil de sauvegarde principal pour le projet.

### Justification

- **Simple à automatiser** avec les scripts (`/scripts/backup.sh` & `/scripts/restore.sh`).  
- Sauvegarde **incrémentale, chiffrée et dédupliquée**.  
- Compatible avec les **backends locaux et distants** (NAS, USB, S3).  
- Format d’archive **autoportant** (chaque repo Restic est autonome).  
- Parfaitement intégré dans un environnement Docker et ZFS (sauvegarde post-snapshot).  
- Pas de dépendances Python → déploiement facile sur VM Debian.

---

## 🧩 Multi-VM adaptation (Intranet / Extranet)

Avec la séparation du projet en deux VMs (ADR-007), la stratégie Restic est adaptée de la manière suivante :

### 🧱 Organisation des dépôts Restic

| VM | Cible | Répertoire | Contenu sauvegardé |
|----|--------|-------------|--------------------|
| **INTRANET** | Local (ZFS) | `/mnt/tank/backups/restic-repo/` | Appdata Docker, bases de données, médias, configs |
| **EXTRANET** | Distant (SFTP vers INTRANET) | `/mnt/tank/backups/extranet/` | NPM configs, certificats SSL, clés OpenVPN |

### 🔁 Règle de restauration

1️⃣ **Restaurer la VM-EXTRANET** (proxy & VPN) — pour retrouver l’accès distant et le réseau HTTPS.  
2️⃣ **Restaurer ensuite la VM-INTRANET** (backends et données).  

Les snapshots ZFS sont restaurés avant le déclenchement de `restic restore`.

### 🔐 Sécurité des sauvegardes
- Chaque dépôt possède son propre mot de passe (`/etc/restic/passwd` sur chaque VM).  
- Les backups sont **chiffrés AES-256** et transférés via **SSH (SFTP)**.  
- Les répertoires `/mnt/tank/backups/` ont des permissions `700` (root uniquement).  
- Aucune clé VPN n’est stockée sur l’INTRANET sans chiffrement.

### 🕓 Fréquences

| Type | VM concernée | Fréquence |
|------|---------------|------------|
| Appdata / bases | INTRANET | Quotidienne |
| Médias / photos | INTRANET | Hebdomadaire |
| Configs NPM / VPN | EXTRANET | Hebdomadaire |
| Vérif intégrité (`restic check`) | INTRANET | Mensuelle |
| Tests de restauration | INTRANET | Mensuelle |

### 🔄 Automatisation
- `backup.sh` et `restore.sh` adaptés par VM (`--repo` spécifique).  
- Cron jobs distincts :  
  - `0 3 * * *` → backup INTRANET  
  - `0 4 * * 7` → backup EXTRANET  
- Logs centralisés sur INTRANET pour supervision (Grafana/Prometheus).

---

## 🔒 Sécurité

- Le mot de passe Restic est stocké dans un fichier sécurisé (`/etc/restic/passwd`, chmod 600).  
- Les sauvegardes sont **chiffrées côté client** avant écriture sur disque ou NAS.  
- Les dumps Postgres/SQLite des services sont inclus dans la sauvegarde avant exécution.

---

## 🔮 Actions suivantes

- [ ] Créer `/scripts/backup-intranet.sh` et `/scripts/backup-extranet.sh`.  
- [ ] Ajouter le plan de rétention dans `/docs/OPERATIONS.md`.  
- [ ] Tester la restauration sur datasets ZFS temporaires.  
- [ ] Mettre à jour Prometheus pour inclure `restic_exporter` (INTRANET).  

---

🗓️ **Journal de bord – 02/11/2025**  
- Mise à jour : ajout de la section “Multi-VM adaptation”.  
- Deux dépôts Restic indépendants (INTRANET / EXTRANET).  
- Sauvegardes chiffrées AES-256, automatisées et supervisées.  
- Procédures cohérentes avec ADR-007/008 et OPERATIONS.md.
