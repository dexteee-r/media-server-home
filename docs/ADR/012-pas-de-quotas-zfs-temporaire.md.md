# ADR 012 : Pas de quotas ZFS (décision temporaire)

## Statut
⏳ **Temporaire** - En attente upgrade matériel (3-6 mois)

## Contexte

Les datasets ZFS permettent de définir des **quotas** pour limiter l'espace disque utilisable par chaque dataset. Cela évite qu'un service (ex: Immich) ne consomme tout l'espace disponible et impacte les autres services.

**Situation actuelle :**
- **Stockage total :** 465 GB (15 GB SSD + 450 GB HDD)
- **Usage actuel :** ~1.5 GB (0.3%)
- **Données volumineuses :** Aucune (pas de médias importés pour l'instant)
- **Upgrade prévu :** Dans 3-6 mois (2x HDD en mirror + backup disk)

**Question :** Doit-on appliquer des quotas ZFS maintenant ou attendre l'upgrade matériel ?

---

## Décision

**Ne PAS appliquer de quotas ZFS pour l'instant.**

Tous les datasets partagent librement l'espace du pool parent :
- `tank-ssd` : 15 GB disponibles pour `appdata` + `postgres`
- `tank-hdd` : 450 GB disponibles pour `media` + `photos` + `backups` + `logs`

**Cette décision est TEMPORAIRE** et sera révisée après l'upgrade matériel.

---

## Raisons

### 1. Stockage limité (500 GB insuffisant)
Le stockage actuel est trop faible pour stocker des données volumineuses :
- ❌ **Collection médias complète** : Nécessite plusieurs To (films + séries + musique)
- ❌ **Bibliothèque photos famille** : Peut atteindre 500 GB - 1 TB
- ✅ **Phase de test seulement** : Quelques médias pour tester les services

**Avec quotas stricts** (ex: 150 GB photos), on limiterait artificiellement un stockage déjà limité.

### 2. Phase de test et développement
Le projet est en phase de **déploiement initial** :
- Jellyfin : Quelques films de test uniquement
- Immich : Photos personnelles limitées (~500 MB actuellement)
- Backups : Configs Docker légères (~1 GB)

**Risque de dépassement quota :** Proche de zéro dans les 3-6 prochains mois.

### 3. Upgrade matériel planifié (3-6 mois)
Un upgrade significatif est budgété :
- **Plan A :** 2x 2 TB HDD en mirror (ZFS RAID1) + 1x 2 TB backup
- **Plan B :** 1x 4 TB HDD + 1x 4 TB backup
- **Budget :** ~200-300€
- **Timeline :** Q1-Q2 2026

**Après upgrade :** Les quotas seront appliqués de manière appropriée (voir plan futur).

### 4. Flexibilité maximale pour tests
Sans quotas, on peut :
- ✅ Tester différents scénarios d'upload (Immich bulk import)
- ✅ Importer temporairement des médias volumineux (tests transcodage)
- ✅ Benchmarker les performances sans contraintes artificielles

**Impact positif :** Accélère la phase de test et validation.

---

## Alternatives considérées

### 1. Appliquer quotas conservateurs ❌

**Exemple de quotas :**
```bash
zfs set quota=10G tank-ssd/appdata
zfs set quota=5G tank-ssd/postgres
zfs set quota=300G tank-hdd/media
zfs set quota=150G tank-hdd/photos
zfs set quota=80G tank-hdd/backups
zfs set quota=20G tank-hdd/logs
```

**Inconvénients :**
- ⚠️ **Limites artificielles** : 150 GB photos trop faible pour usage réel
- ⚠️ **Complexité inutile** : Gestion de quotas alors qu'il n'y a presque aucune donnée
- ⚠️ **Risque blocage** : Si on importe 200 GB de photos en test → erreur quota

**Verdict :** Apporte plus de contraintes que de bénéfices.

---

### 2. Quotas "larges" (90% du pool) ❌

**Exemple :**
```bash
zfs set quota=400G tank-hdd/photos  # 89% du pool
```

**Inconvénients :**
- ⚠️ **Inutile** : Si le quota est à 90%, autant ne pas en mettre
- ⚠️ **Fausse sécurité** : Le quota ne protège de rien si fixé si haut

**Verdict :** Pas de valeur ajoutée.

---

### 3. Monitoring sans quotas ✅ (choisi)

**Principe :** Surveiller l'usage via Prometheus + alertes si > 80%.

**Avantages :**
- ✅ **Flexibilité** : Pas de limite artificielle
- ✅ **Visibilité** : Dashboard Grafana montre usage en temps réel
- ✅ **Alertes** : Email si un dataset dépasse 80% (temps de réagir)

**Verdict :** Meilleur compromis pour la phase actuelle.

---

## Plan futur (après upgrade matériel)

### Quotas prévus après upgrade vers 2-4 TB
```bash
# Pool SSD (20-30 GB après upgrade RAM et expansion)
zfs set quota=20G tank-ssd/appdata
zfs set quota=10G tank-ssd/postgres

# Pool HDD (2-4 TB après upgrade)
zfs set quota=1T tank-hdd/media      # Vidéos Jellyfin
zfs set quota=500G tank-hdd/photos   # Photos Immich
zfs set quota=200G tank-hdd/backups  # Sauvegardes Restic
zfs set quota=50G tank-hdd/logs      # Logs services
```

**Logique :**
- **Media (1 TB)** : Collection films + séries + musique
- **Photos (500 GB)** : 10 ans de photos famille haute résolution
- **Backups (200 GB)** : Snapshots ZFS + exports Restic
- **Logs (50 GB)** : Rétention 90 jours maximum

---

## Conséquences

### Positives ✅

1. **Flexibilité maximale**
   - Tests sans contraintes artificielles
   - Import de médias volumineux possible (benchmarks)
   - Pas de gestion complexe de quotas

2. **Simplification**
   - Moins de complexité opérationnelle
   - Pas de risques d'erreurs "quota exceeded" pendant les tests
   - Focus sur le déploiement des services

3. **Monitoring actif**
   - Dashboard Grafana avec usage ZFS en temps réel
   - Alertes configurées si usage > 80%
   - Visibilité complète sur la consommation

### Négatives ⚠️

1. **Risque de remplissage accidentel**
   - **Scénario :** Upload massif Immich sans surveillance
   - **Impact :** Disque plein → services impactés
   - **Mitigation :** Monitoring Grafana + alertes à 80%

2. **Pas de protection par dataset**
   - **Scénario :** Un service "fou" consomme tout l'espace
   - **Impact :** Autres services affectés
   - **Mitigation :** Monitoring + intervention manuelle rapide

3. **Discipline requise**
   - **Besoin :** Vérifier régulièrement `zfs list`
   - **Impact :** Si oublié, risque saturation
   - **Mitigation :** Cron hebdomadaire `zfs-check-usage.sh`

---

## Monitoring mis en place

### 1. Dashboard Grafana

**Métriques ZFS surveillées :**
- Usage par dataset (GB et %)
- Taux de compression
- IOPS lecture/écriture
- Latence moyenne

**Alertes configurées :**
- ⚠️ Warning : Usage > 70% d'un dataset
- 🚨 Critical : Usage > 85% d'un dataset

### 2. Script de vérification hebdomadaire
```bash
# /root/zfs-check-usage.sh (Proxmox)
#!/bin/bash
echo "=== ZFS Usage Report ==="
zfs list -o name,used,avail,refer,quota

# Alerte si > 80%
zfs list -H -o name,used,avail | while read name used avail; do
  # Calcul % usage (simplifié)
  echo "$name : $used / $avail"
done
```

**Cron :** Tous les lundis 9h00 + envoi email si > 80%

---

## Validation

### Critères de succès (3-6 mois)
- ✅ Aucun dataset ne dépasse 90% d'usage
- ✅ Alertes Grafana fonctionnelles (testées)
- ✅ Pas de service impacté par manque d'espace
- ✅ Upgrade matériel effectué dans les délais

### Critères de révision (après upgrade)
- Application des quotas selon le plan futur
- Réévaluation des besoins (collection médias réelle)
- Ajustement des quotas si nécessaire

---

## Références

- [ZFS Quotas and Reservations](https://docs.oracle.com/cd/E19253-01/819-5461/gazvb/index.html)
- [Best Practices for ZFS in Homelab](https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/)

---

## Décision prise par
- Markus (propriétaire projet)
- Claude (Anthropic AI assistant)

## Date
11 novembre 2025

## Révision prévue
**Q1-Q2 2026** - Après upgrade matériel (2x HDD mirror + backup)

## Critères de révision
- Upgrade matériel effectué
- Capacité totale > 2 TB
- Début import collection médias complète

À ce moment, appliquer les quotas selon le plan futur ci-dessus.