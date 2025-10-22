# ADR-007 — Stratégie de répartition stockage : **SSD/HDD**

## 📘 Contexte

Le projet **media-server-home** s'exécute sur un **Dell OptiPlex 7040** avec :
- **SSD NVMe 256 Go** (Samsung MZVLW256, santé 98%, Windows 11 actuellement installé)
- **HDD 500 Go** (nouveau, ajouté récemment, prévu pour upgrade futur)
- **16 Go RAM DDR4** (validation ZFS)
- **Pas d'emplacement supplémentaire** pour disque additionnel

L'objectif est de **maximiser les performances** et la **durée de vie** des disques en répartissant intelligemment les données selon leurs caractéristiques d'accès (IOPS vs séquentiel, lecture vs écriture).

---

## ⚙️ Problème à résoudre

Déterminer **quelle donnée sur quel disque** pour :
1. Optimiser les performances des services critiques (DB, Docker).
2. Préserver la durée de vie du SSD (limiter les écritures).
3. Exploiter au mieux la capacité du HDD (médias volumineux).
4. Anticiper un upgrade HDD futur sans refonte complète.

---

## 🧩 Analyse des types de données

| Type de donnée | Volume | Accès | IOPS | Écriture | Disque idéal |
|----------------|--------|-------|------|----------|--------------|
| **Proxmox VE** | ~20 Go | Lecture fréquente | Élevé | Faible | SSD |
| **VM Ubuntu OS** | ~15 Go | Lecture fréquente | Élevé | Moyenne | SSD |
| **Docker images** | ~10 Go | Lecture fréquente | Élevé | Moyenne | SSD |
| **Postgres DB (Immich)** | ~5-10 Go | Random I/O intense | Très élevé | Élevée | SSD |
| **Configs (appdata)** | ~5-10 Go | Lecture/écriture fréquente | Élevé | Moyenne | SSD |
| **Logs** | ~2-5 Go | Écriture continue | Moyen | Élevée | HDD (rotation) |
| **Vidéos Jellyfin** | ~200-300 Go | Séquentiel lecture | Faible | Nulle | HDD |
| **Photos Immich** | ~50-100 Go | Séquentiel lecture | Faible | Moyenne | HDD |
| **Backups Restic** | ~50-100 Go | Séquentiel écriture | Faible | Élevée | HDD |

---

## 🧮 Options étudiées

### Option A : Tout sur SSD (sauf médias)
```
SSD 256 Go : Proxmox + VM + appdata + postgres + logs
HDD 500 Go : médias + photos + backups
```
**Avantages** : performances maximales  
**Inconvénients** : usure SSD rapide (logs), capacité SSD limitée

---

### Option B : Séparation stricte performance/capacité (recommandée)
```
SSD 256 Go : Proxmox + VM + appdata + postgres (données critiques)
HDD 500 Go : médias + photos + backups + logs (données volumineuses)
```
**Avantages** : équilibre perf/durabilité, upgrade HDD simple  
**Inconvénients** : logs sur HDD (acceptable)

---

### Option C : Tout sur HDD (sauf OS)
```
SSD 256 Go : Proxmox + VM OS uniquement
HDD 500 Go : appdata + postgres + médias + photos + backups
```
**Avantages** : préserve SSD  
**Inconvénients** : performances DB dégradées, inacceptable pour Postgres

---

## ✅ Décision finale

> **Adopté : Option B — Séparation performance (SSD) / capacité (HDD)**

### Répartition détaillée

#### 🔵 SSD NVMe 256 Go (Samsung MZVLW256)
```
Total : 256 Go
├─ Proxmox VE 8.2 : 20 Go
├─ VM "Services" Ubuntu 24.04 : 40 Go
│  ├─ OS + Docker Engine : 15 Go
│  ├─ Images Docker : 10 Go
│  └─ Cache système : 5 Go
└─ ZFS pool "tank-ssd" : 150 Go (utilisable ~140 Go)
   ├─ tank-ssd/appdata : 30 Go (configs Docker)
   │  ├─ jellyfin/config : 2 Go
   │  ├─ immich/config : 5 Go
   │  ├─ traefik/config : 500 Mo
   │  ├─ prometheus/data : 10 Go
   │  └─ grafana/data : 2 Go
   └─ tank-ssd/postgres : 20 Go (DB Immich + WAL)

Réserve libre : ~50 Go (snapshots, évolution)
```

**Justification SSD :**
- **Postgres** : base de données critique, random I/O intense
- **Appdata** : configurations accédées fréquemment (Traefik, Prometheus)
- **Performances** : temps de démarrage conteneurs, requêtes DB rapides

**Configuration ZFS SSD :**
```bash
zfs set compression=lz4 tank-ssd
zfs set recordsize=16K tank-ssd/postgres  # Optimisé DB
zfs set recordsize=128K tank-ssd/appdata
zfs set atime=off tank-ssd
zfs set sync=standard tank-ssd
```

---

#### 🟠 HDD 500 Go (SATA 5400 RPM)
```
Total : 500 Go
└─ ZFS pool "tank-hdd" : 450 Go (utilisable ~400 Go)
   ├─ tank-hdd/media : 250 Go (vidéos Jellyfin)
   ├─ tank-hdd/photos : 100 Go (uploads Immich)
   ├─ tank-hdd/backups : 50 Go (Restic repo)
   └─ tank-hdd/logs : 10 Go (rotation 30j)

Réserve libre : ~40 Go (évolution)
```

**Justification HDD :**
- **Médias** : accès séquentiel, lecture seule, volume important
- **Photos** : idem, uploads occasionnels
- **Backups** : écriture séquentielle, déduplication Restic
- **Logs** : écriture continue, rotation automatique

**Configuration ZFS HDD :**
```bash
zfs set compression=lz4 tank-hdd
zfs set recordsize=1M tank-hdd/media      # Streaming vidéo
zfs set recordsize=128K tank-hdd/photos   # Photos
zfs set recordsize=128K tank-hdd/backups
zfs set recordsize=128K tank-hdd/logs
zfs set atime=off tank-hdd
```

---

## 🔁 Conséquences & impacts

### Performances attendues

| Service | Performance | Temps de réponse |
|---------|-------------|------------------|
| **Jellyfin (streaming 1080p)** | ✅ Fluide | HDD séquentiel suffisant |
| **Immich (upload photo)** | ✅ Rapide | HDD écriture ok, DB sur SSD |
| **Immich (parcours albums)** | ✅ Instantané | Métadonnées Postgres sur SSD |
| **Traefik (routage)** | ✅ <10ms | Config sur SSD |
| **Prometheus (query)** | ✅ Rapide | TSDB sur SSD |
| **Grafana (dashboards)** | ✅ <1s | DB sur SSD |
| **Backup Restic** | ⚠️ 2-4h (400 Go) | HDD séquentiel limite |

### Durée de vie SSD

**Estimation writes quotidiens :**
```
Postgres WAL : 2 Go/jour
Docker logs → HDD : 0 Go/jour (redirigé)
Appdata configs : 500 Mo/jour
Snapshots ZFS : 1 Go/jour
Total : ~3.5 Go/jour = ~1.3 To/an
```

**TBW Samsung 256 Go :**
- Garantie constructeur : ~150 TBW
- Actuellement écrit : ~9 TBW
- Écriture annuelle : ~1.3 TBW
- **Durée de vie estimée : 100+ ans** (largement suffisant)

---

## 🔮 Évolution future : upgrade HDD

### Plan de migration HDD 500 Go → 2 To

**Déclencheur :** Utilisation >80% du HDD (320 Go utilisés)

**Procédure :**
```bash
# 1. Backup Restic complet
restic backup /mnt/tank-hdd --tag pre-upgrade

# 2. Arrêt services Docker
docker compose down

# 3. Snapshot ZFS avant export
zfs snapshot -r tank-hdd@migrate

# 4. Export pool (si remplacement physique)
zpool export tank-hdd

# 5. Remplacer physiquement le disque (arrêt machine)

# 6. Import pool sur nouveau disque
zpool import tank-hdd

# 7. Vérifier intégrité
zpool status tank-hdd
zfs list

# 8. Redémarrer services
docker compose up -d

# 9. Vérifier fonctionnement
/scripts/healthcheck.sh
```

**Capacité après upgrade 2 To :**
```
tank-hdd/media : 1 To (films/séries)
tank-hdd/photos : 500 Go (photos famille)
tank-hdd/backups : 300 Go (Restic + snapshots)
tank-hdd/logs : 20 Go
Réserve : 180 Go
```

---

## 🔒 Sécurité et résilience

### Stratégie de sauvegarde

| Dataset | Fréquence snapshot ZFS | Backup Restic | Destination externe |
|---------|------------------------|---------------|---------------------|
| **tank-ssd/postgres** | Quotidien (7j) | Quotidien | NAS SFTP |
| **tank-ssd/appdata** | Quotidien (7j) | Quotidien | NAS SFTP |
| **tank-hdd/photos** | Hebdomadaire (4 semaines) | Hebdomadaire | Cloud S3 |
| **tank-hdd/media** | Mensuel (3 mois) | Mensuel | HDD USB |
| **tank-hdd/backups** | - | - | - (repo Restic) |

### Point de défaillance unique

**Risque identifié :** Un seul disque par type (1 SSD, 1 HDD)

**Mitigation :**
- Backups externes quotidiens (Restic)
- Snapshots ZFS locaux (restauration rapide)
- Monitoring SMART (alertes Prometheus)
- Budget upgrade : HDD 2 To + HDD 500 Go en miroir ZFS (futur)

---

## 📊 Monitoring et alertes

### Métriques Prometheus à surveiller

```yaml
# /configs/prometheus/alerts/storage.yml
groups:
  - name: storage
    rules:
      - alert: SSDUsageHigh
        expr: node_filesystem_avail_bytes{mountpoint="/mnt/tank-ssd"} / node_filesystem_size_bytes < 0.15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "SSD usage >85%"

      - alert: HDDUsageHigh
        expr: node_filesystem_avail_bytes{mountpoint="/mnt/tank-hdd"} / node_filesystem_size_bytes < 0.20
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "HDD usage >80% - prévoir upgrade"

      - alert: SSDHealthDegraded
        expr: smartctl_device_health_status != 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "SSD health issue detected"
```

---

## 🧩 Tableau récapitulatif

| Critère | SSD NVMe 256 Go | HDD 500 Go |
|---------|-----------------|------------|
| **Usage** | OS, VM, DB, configs | Médias, photos, backups, logs |
| **IOPS** | ~50K read / 30K write | ~100 read / 100 write |
| **Throughput** | ~2 Go/s read / 1 Go/s write | ~150 Mo/s read/write |
| **Latence** | <1ms | ~10-15ms |
| **Durée de vie** | >100 ans (usage prévu) | >5 ans (24/7) |
| **Capacité utilisée** | ~200 Go / 256 Go | ~360 Go / 500 Go |
| **Upgrade prévu** | Non | Oui (2 To dans 6-12 mois) |

---

## 🔮 Actions suivantes

- [ ] Installer Proxmox VE 8.2 sur SSD NVMe (wipe Windows 11)
- [ ] Créer pool ZFS `tank-ssd` sur partition SSD restante (~150 Go)
- [ ] Créer pool ZFS `tank-hdd` sur HDD 500 Go complet
- [ ] Configurer datasets ZFS selon répartition définie
- [ ] Créer VM Ubuntu "Services" avec disque virtuel 40 Go sur SSD
- [ ] Monter datasets ZFS dans VM via bind mounts
- [ ] Configurer Prometheus alerting sur usage disques
- [ ] Documenter procédure upgrade HDD dans `OPERATIONS.md`
- [ ] Budgétiser HDD 2 To (Western Digital Red/Seagate IronWolf)

---

🗓️ **Journal de bord — 23/10/2025**  
- Décision : répartition SSD (performance) / HDD (capacité)
- Justification : maximise performances DB/configs, préserve SSD, anticipe upgrade HDD
- Configuration : 16 Go RAM valide ZFS sur les 2 disques
- Étape suivante : guide de migration Windows 11 → Proxmox VE 8.2

---

### 💡 Résumé pour ton Wiki

> **ADR-007 — Stratégie stockage SSD/HDD**  
> - **SSD 256 Go** : Proxmox + VM + appdata + Postgres (perf critiques)  
> - **HDD 500 Go** : médias + photos + backups + logs (capacité)  
> - ZFS sur les 2 disques avec recordsize optimisé  
> - Upgrade HDD prévu (2 To dans 6-12 mois)  
> - Durée de vie SSD estimée : 100+ ans