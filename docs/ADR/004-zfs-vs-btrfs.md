# ADR-004 — Choix du système de fichiers : **ZFS vs Btrfs**

## 📘 Contexte

Le projet **media-server-home** repose sur une machine hôte **Dell Optiplex 7040 (i5-6500, 8–16 Go RAM)** sous **Proxmox VE 8**.  
L’objectif est de stocker durablement :

- les **médias (vidéos, photos)**,  
- les **volumes applicatifs** (Jellyfin, Immich, Postgres, Traefik, etc.),  
- les **sauvegardes** (snapshots, dumps, Restic/Borg).

Le système doit offrir :
- intégrité des données à long terme,
- snapshots cohérents,
- gestion simple des disques,
- performances stables pour le streaming.

Deux systèmes modernes sont envisageables : **ZFS** (OpenZFS) et **Btrfs** (B-tree FS).

---

## ⚙️ Problème à résoudre

Déterminer quel **système de fichiers** utiliser pour :
- les datasets de stockage (`/media`, `/photos`, `/appdata`, `/backups`),
- les volumes de la VM “Services” (montages NFS ou bind mounts),
- les sauvegardes locales et distantes.

Les critères clés sont :
- robustesse et intégrité ;
- facilité d’administration sur Proxmox ;
- compatibilité avec snapshots et quotas ;
- performances pour le streaming vidéo/photo.

---

## 🧩 Options étudiées

| Option | Avantages | Inconvénients |
|--------|------------|---------------|
| **ZFS (OpenZFS)** | • Vérification d’intégrité et auto-réparation des blocs corrompus.<br>• Snapshots et clones instantanés.<br>• Compression transparente (lz4).<br>• Parfaitement intégré à Proxmox VE (GUI, backup, replication).<br>• Bonnes performances séquentielles (médias). | • Consommation mémoire plus élevée (≈ 1 Go RAM par To de pool recommandé).<br>• Configuration un peu plus complexe (zpool, zfs dataset). |
| **Btrfs** | • Intégré nativement à Linux (aucune dépendance).<br>• Snapshots rapides par sous-volumes.<br>• Compression possible (zstd).<br>• Moins exigeant en RAM.<br>• Bon support de Restic et Borg. | • Moins robuste sur volumes très gros ou très actifs (scrub lent).<br>• Gestion multi-disque moins fiable que ZFS (RAID 5/6 instable).<br>• Moins intégré dans Proxmox (pas de GUI complète). |

---

## 🧮 Critères de décision

| Critère | Pondération | ZFS | Btrfs |
|----------|--------------|-----|-------|
| **Intégrité des données / checksums** | 5 | ✅ Parfaite (scrub, auto-heal) | ⚠️ Bonne mais partielle |
| **Intégration Proxmox VE (GUI, snapshots, backup)** | 5 | ✅ Native | ⚠️ Limitée |
| **Snapshots / clones** | 4 | ✅ Instantanés + envoi incrémental | ✅ Rapides (sous-volumes) |
| **Performance streaming (séquentiel)** | 4 | ✅ Excellente | ⚠️ Moyenne |
| **Consommation mémoire** | 3 | ⚠️ Légère surconsommation | ✅ Faible |
| **Administration / maintenance** | 3 | ⚠️ Commandes ZFS spécifiques | ✅ Simple (mount natif) |
| **Compatibilité Docker / VM** | 3 | ✅ Montages simples via bind | ✅ Idem |
| **Sauvegarde / snapshot distant** | 3 | ✅ `zfs send/recv`, export Restic | ⚠️ `btrfs send` moins intégré |
| **Évolutivité multi-disques** | 4 | ✅ Stable (RAID Z) | ⚠️ Fragile (RAID 5/6 instable) |
| **Score total (/34)** | — | **31 / 34** | **26 / 34** |

---

## ✅ Décision finale

> **Adopté : ZFS comme système de fichiers principal.**

### Justification

- ZFS offre la **meilleure fiabilité à long terme** pour un serveur 24/7.  
- Parfaite **intégration à Proxmox** : snapshots, backup, GUI, monitoring.  
- Excellente **performance séquentielle**, idéale pour le streaming vidéo.  
- Gestion robuste des **pools et datasets** : facile à séparer entre `media`, `appdata`, `backups`.  
- Sauvegardes incrémentales et **envoi distant possible** (`zfs send | ssh`).  
- Scrub et auto-repair préviennent les corruptions silencieuses.

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|--------|--------|
| **Structure du pool** | Création du pool `tank` sur le HDD principal (ou miroir si 2 disques). |
| **Datasets à prévoir** | `tank/media`, `tank/photos`, `tank/appdata`, `tank/backups`. |
| **Compression / cache** | Activer `compression=lz4`, `atime=off`, `recordsize=1M` pour médias. |
| **Snapshots automatiques** | Planifier via `zfs-auto-snapshot` (quotidien/hebdo/mensuel). |
| **Sauvegardes Restic/Borg** | Point de montage sur `/mnt/tank/backups` pour dump et sync. |
| **RAM** | 16 Go RAM disponible, performances garanties |
| **Évolution future** | Migration facile vers miroir ZFS (ajout disque). |

---

## 🔮 Actions suivantes

- [ ] Initialiser le pool : `zpool create tank /dev/sdX`  
- [ ] Créer datasets : `zfs create tank/media` etc.  
- [ ] Activer compression : `zfs set compression=lz4 tank`  
- [ ] Configurer snapshots auto via `zfs-auto-snapshot`.  
- [ ] Documenter les mounts et points de partage dans `/infra/storage/mounts.md`.  
- [ ] Préparer ADR-005 : **Stratégie de sauvegarde (Restic vs Borg)**.

---

🗓️ **Journal de bord Future desicion**  
- Décision : adoption de **ZFS** comme système de fichiers principal.  
- Raisons : intégrité, intégration Proxmox, performance séquentielle.  
- Étape suivante : définir la **stratégie de sauvegarde (ADR-005)** et les points de montage.
