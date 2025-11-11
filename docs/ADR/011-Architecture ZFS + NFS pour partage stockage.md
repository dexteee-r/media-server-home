# ADR 011 : Architecture ZFS + NFS pour partage stockage

## Statut
✅ **Accepté et implémenté** (11 novembre 2025)

## Contexte

Le projet nécessite de partager le stockage physique (SSD NVMe + HDD) entre l'hôte Proxmox et les VMs pour :
- Stocker les configurations Docker (appdata)
- Héberger les bases de données (PostgreSQL)
- Gérer les médias volumineux (vidéos Jellyfin, photos Immich)
- Centraliser les backups (Restic)

**Contraintes matérielles :**
- 256 GB SSD NVMe (partagé entre Proxmox + VMs + stockage rapide)
- 500 GB HDD (dédié au stockage de masse)
- 2 VMs QEMU/KVM (pas LXC)
- Besoin de snapshots pour backups

**Question technique :** Où créer les pools ZFS et comment les partager avec les VMs ?

---

## Décision

**Créer les pools ZFS sur l'hôte Proxmox, puis partager via NFS vers les VMs.**

### Architecture implémentée
```
Proxmox VE 8.4 (hôte)
├─ Pools ZFS créés ici
│  ├─ tank-ssd (15 GB sur LVM)
│  │  ├─ appdata  (configs Docker)
│  │  └─ postgres (bases de données)
│  └─ tank-hdd (450 GB sur /dev/sda)
│     ├─ media    (vidéos Jellyfin)
│     ├─ photos   (photos Immich)
│     ├─ backups  (sauvegardes Restic)
│     └─ logs     (logs services)
│
├─ Serveur NFS (nfs-kernel-server)
│  └─ 6 exports configurés (/etc/exports)
│
└─ VMs (clients NFS)
   ├─ VM-INTRANET : 5 montages NFS
   │  ├─ /mnt/appdata  → tank-ssd/appdata
   │  ├─ /mnt/postgres → tank-ssd/postgres
   │  ├─ /mnt/media    → tank-hdd/media
   │  ├─ /mnt/photos   → tank-hdd/photos
   │  └─ /mnt/backups  → tank-hdd/backups
   │
   └─ VM-EXTRANET : 1 montage NFS
      └─ /mnt/logs     → tank-hdd/logs
```

### Montages NFS persistants
- Configuration : `/etc/fstab` avec option `_netdev`
- Protocole : NFSv4 (par défaut)
- Permissions : `no_root_squash` (root VM = root Proxmox)
- Synchronisation : `sync` (données écrites immédiatement)

---

## Alternatives considérées

### 1. ZFS dans les VMs ❌ (rejeté)

**Principe :** Passer les disques bruts aux VMs (`/dev/sda`) et créer les pools ZFS à l'intérieur.

**Avantages :**
- Autonomie complète des VMs
- Pas de dépendance réseau

**Inconvénients (critiques) :**
- ❌ **Perte de contrôle Proxmox** : L'hôte ne voit plus le disque
- ❌ **Pas de snapshots centralisés** : Chaque VM gère ses propres snapshots
- ❌ **Monitoring SMART impossible** : Proxmox ne peut plus surveiller la santé du disque
- ❌ **Performance dégradée** : Double couche de virtualisation (VM + ZFS)
- ❌ **Pas de partage entre VMs** : Impossible de partager des datasets

**Verdict :** Trop de limitations pour un gain marginal.

---

### 2. Bind mounts Proxmox ❌ (impossible)

**Principe :** Utiliser `mp0: /tank-hdd/media,mp=/mnt/media` dans la config Proxmox.

**Avantages :**
- Performance native (pas de réseau)
- Simple à configurer

**Inconvénients (bloquants) :**
- ❌ **Fonctionne UNIQUEMENT avec LXC** : Pas compatible QEMU/KVM
- ❌ **Architecture LXC non retenue** : Voir ADR 002 (Docker Compose dans VMs)

**Verdict :** Techniquement impossible avec des VMs QEMU.

---

### 3. iSCSI ❌ (overkill)

**Principe :** Exposer les volumes ZFS via iSCSI (block-level).

**Avantages :**
- Performance block-level (meilleure que NFS)
- Standard pour SAN

**Inconvénients :**
- ⚠️ **Complexité excessive** : Configuration lourde (targets, LUNs, initiators)
- ⚠️ **Overkill pour homelab** : Destiné aux environnements entreprise
- ⚠️ **Pas de partage simultané** : Un volume iSCSI = une VM

**Verdict :** Trop complexe pour le besoin.

---

### 4. CIFS/Samba ❌ (performance)

**Principe :** Partager via SMB/CIFS au lieu de NFS.

**Avantages :**
- Compatible Windows (si besoin futur)

**Inconvénients :**
- ⚠️ **Performance inférieure** : Overhead plus important que NFS
- ⚠️ **Complexité auth** : Gestion des utilisateurs Samba
- ⚠️ **Moins adapté Linux** : NFS est natif et plus performant

**Verdict :** NFS plus adapté pour un environnement Linux pur.

---

### 5. ZFS + NFS ✅ (choisi)

**Avantages :**
- ✅ **Snapshots centralisés** : `zfs snapshot` depuis Proxmox pour toutes les VMs
- ✅ **SMART monitoring** : Proxmox surveille la santé des disques
- ✅ **Compression ZFS** : LZ4 transparent (gain 30-50%)
- ✅ **Intégrité des données** : Checksums ZFS automatiques
- ✅ **Partage flexible** : Facile d'ajouter de nouvelles VMs
- ✅ **Performance acceptable** : Overhead NFS ~1-2ms (imperceptible pour média/photos)
- ✅ **Scalabilité** : Ajout de VMs sans modifier l'infrastructure

**Inconvénients (acceptables) :**
- ⚠️ **Overhead réseau** : ~5% de latence supplémentaire (négligeable)
- ⚠️ **Dépendance réseau** : Si NFS down, les VMs sont impactées (rare)
- ⚠️ **Point unique de défaillance** : Proxmox doit être up (mais nécessaire de toute façon)

**Verdict :** Meilleur compromis flexibilité/performance/simplicité.

---

## Conséquences

### Positives ✅

1. **Gestion centralisée**
   - Tous les snapshots ZFS depuis Proxmox
   - Monitoring unifié des disques (SMART)
   - Backups simplifiés (`zfs send/receive`)

2. **Flexibilité**
   - Ajout de VMs simple : juste créer un export NFS
   - Partage possible entre plusieurs VMs
   - Migration VM facile (montages NFS suivent la VM)

3. **Performance**
   - SSD pour données chaudes (DB, configs) = rapide
   - HDD pour données froides (vidéos, photos) = économique
   - Compression ZFS transparente (gain espace sans perte vitesse)

4. **Sécurité des données**
   - Checksums ZFS (détection corruption)
   - Snapshots réguliers (protection erreurs)
   - Backups chiffrés Restic sur les datasets

### Négatives ⚠️

1. **Overhead réseau**
   - Latence ~1-2ms supplémentaire (vs accès direct)
   - Bande passante Gigabit suffisante mais pas 10G
   - Impact : Imperceptible pour streaming média

2. **Dépendance infrastructure**
   - Si Proxmox down → VMs inaccessibles (évident)
   - Si NFS service crash → VMs bloquées (rare, service stable)
   - Mitigation : Monitoring NFS dans Prometheus

3. **Gestion permissions**
   - `no_root_squash` nécessaire (root VM = root Proxmox)
   - Risque sécurité si VM compromise (acceptable en homelab)
   - Mitigation : UFW + isolation réseau VM-EXTRANET/INTRANET

---

## Implémentation

### Pools ZFS créés
```bash
# Pool SSD (15 GB sur LVM)
zpool create -o ashift=12 -O compression=lz4 -O atime=off tank-ssd /dev/pve/zfs-ssd
zfs create tank-ssd/appdata
zfs create tank-ssd/postgres

# Pool HDD (450 GB sur disque complet)
zpool create -o ashift=12 -O compression=lz4 -O atime=off tank-hdd /dev/sda
zfs create tank-hdd/media
zfs create tank-hdd/photos
zfs create tank-hdd/backups
zfs create tank-hdd/logs
```

### Serveur NFS (Proxmox)
```bash
# /etc/exports
/tank-ssd/appdata 192.168.1.101(rw,sync,no_subtree_check,no_root_squash)
/tank-ssd/postgres 192.168.1.101(rw,sync,no_subtree_check,no_root_squash)
/tank-hdd/media 192.168.1.101(rw,sync,no_subtree_check,no_root_squash)
/tank-hdd/photos 192.168.1.101(rw,sync,no_subtree_check,no_root_squash)
/tank-hdd/backups 192.168.1.101(rw,sync,no_subtree_check,no_root_squash)
/tank-hdd/logs 192.168.1.111(rw,sync,no_subtree_check,no_root_squash)
```

### Clients NFS (VMs)
```bash
# /etc/fstab (VM-INTRANET)
192.168.1.100:/tank-ssd/appdata  /mnt/appdata  nfs  defaults,_netdev  0  0
192.168.1.100:/tank-ssd/postgres /mnt/postgres nfs  defaults,_netdev  0  0
192.168.1.100:/tank-hdd/media    /mnt/media    nfs  defaults,_netdev  0  0
192.168.1.100:/tank-hdd/photos   /mnt/photos   nfs  defaults,_netdev  0  0
192.168.1.100:/tank-hdd/backups  /mnt/backups  nfs  defaults,_netdev  0  0

# /etc/fstab (VM-EXTRANET)
192.168.1.100:/tank-hdd/logs     /mnt/logs     nfs  defaults,_netdev  0  0
```

---

## Validation

### Tests effectués
- ✅ Montages NFS persistants après reboot VMs
- ✅ Performance streaming Jellyfin (aucun lag perceptible)
- ✅ Uploads photos Immich (bande passante saturée avant NFS)
- ✅ Snapshots ZFS depuis Proxmox (fonctionnels)
- ✅ SMART monitoring disques (visible dans Proxmox)

### Métriques
- Latence NFS : ~1ms (mesurée avec `ping` + `iperf3`)
- Bande passante : 940 Mbps (limite Gigabit atteinte)
- Overhead CPU NFS : <1% (négligeable)

---

## Références

- [Proxmox VE - NFS Storage](https://pve.proxmox.com/wiki/Storage:_NFS)
- [ZFS on Linux - Best Practices](https://openzfs.github.io/openzfs-docs/)
- [Reddit r/homelab - ZFS + NFS discussion](https://reddit.com/r/homelab)

---

## Décision prise par
- Markus (propriétaire projet)
- Claude (Anthropic AI assistant)

## Date
11 novembre 2025

## Révision prévue
Après upgrade stockage matériel (3-6 mois) : Réévaluer si nécessaire.