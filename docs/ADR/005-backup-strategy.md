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
| **Restic** | - 100 % Go → binaire statique, aucune dépendance.<br>- Sauvegarde incrémentale dédupliquée et **chiffrée** (AES-256).<br>- Support de multiples backends : local, SFTP, SMB, rclone, cloud (Backblaze, AWS, etc.).<br>- Commandes simples (`restic backup`, `restic restore`, `forget`, `prune`).<br>- Bonne intégration dans scripts Bash et Docker. | - Moins efficace que Borg pour très grands ensembles de fichiers non compressibles.<br>- Pas de compression native (seulement chiffrage). |
| **BorgBackup** | - Très haute déduplication + compression intégrée (zlib/lz4).<br>- Extrêmement efficace sur gros volumes récurrents.<br>- Vérification d’intégrité puissante (`borg check`). | - Nécessite Python et dépendances.<br>- Moins compatible multi-backend (pas de S3 natif sans BorgBase ou rclone).<br>- Moins portable (archives pas autoportantes). |

---

## 🧮 Critères de décision

| Critère | Pondération | Restic | BorgBackup |
|----------|--------------|--------|-------------|
| **Chiffrement intégré** | 5 | ✅ AES-256 natif | ✅ |
| **Déduplication efficace** | 4 | ✅ Bonne | ✅ Excellente |
| **Compression** | 3 | ⚠️ Non native | ✅ Intégrée |
| **Support multi-destination (SFTP / Cloud)** | 5 | ✅ Large (SFTP, SMB, S3, rclone) | ⚠️ Limité |
| **Intégration Docker / scripts shell** | 4 | ✅ Simple (`restic` CLI) | ⚠️ Plus complexe |
| **Performances globales (backup/restore)** | 4 | ✅ Très bonnes | ✅ Excellentes |
| **Maintenance / dépendances** | 3 | ✅ Binaire unique | ⚠️ Dépend de Python |
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
- Pas de dépendances Python → déploiement facile sur VM Ubuntu.

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Scripts** | Création de `/scripts/backup.sh` et `/scripts/restore.sh` avec variables (`RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`). |
| **Planification** | Cron job journalier (ex: `0 3 * * * /scripts/backup.sh`). |
| **Structure du dépôt** | Ajout du fichier `.env.example` avec variables Restic. |
| **Stockage** | Repo local par défaut : `/mnt/tank/backups/restic-repo`. |
| **Sauvegarde distante** | Optionnelle : via `restic -r sftp:user@nas:/backups`. |
| **Surveillance** | Logs redirigés vers `/var/log/restic.log` + dashboard Grafana (export Promtail). |
| **Restauration** | Procédure documentée dans `/docs/OPERATIONS.md`. |

---

## 🧩 Exemple de configuration (env)

```bash
# .env.example
RESTIC_REPOSITORY=/mnt/tank/backups/restic-repo
RESTIC_PASSWORD_FILE=/etc/restic/passwd
RESTIC_RETENTION="--keep-daily 7 --keep-weekly 4 --keep-monthly 3"
```

## 🔒 Sécurité
- Le mot de passe Restic est stocké dans un fichier sécurisé (/etc/restic/passwd, chmod 600).
- Les sauvegardes sont chiffrées côté client avant écriture sur disque ou NAS.
- Les dumps Postgres/SQLite des services sont inclus dans la sauvegarde avant exécution.


## 🔮 Actions suivantes

- Créer /scripts/backup.sh et /scripts/restore.sh.
- Ajouter le plan de rétention dans /docs/OPERATIONS.md.
- Tester une restauration complète sur dataset temporaire.
- Préparer ADR-006 — Monitoring (Prometheus + Grafana) pour surveiller la santé et les sauvegardes.


### 💡 Résumé pour ton Wiki

**ADR-005 — Sauvegarde : Restic adopté.**  
Motifs : simplicité, chiffrement natif, intégration Docker, multi-backend (local + NAS + S3).  
Impact : scripts `/scripts/backup.sh` et `/scripts/restore.sh`, repo local `/mnt/tank/backups/restic-repo`.


🗓️ **Journal de bord Future desicion**

- Décision : adoption de Restic comme outil de sauvegarde.
- Raisons : simplicité, chiffrement intégré, compatibilité Docker & multi-backend.
- Étape suivante : documentation de la stack de monitoring (ADR-006).