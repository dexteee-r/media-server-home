## Déploiement initial
- Commandes bootstrap
- Vérification post-install

## Opérations courantes
- Backup manuel / test restore
- Update stack (Watchtower + manual)
- Ajout utilisateur Jellyfin/Immich
- Rotation logs

## Troubleshooting
- Conteneur ne démarre pas
- Erreur transcodage Jellyfin
- Postgres corrompue
- Espace disque plein

## Remplacement HDD

1. Backup Restic complet
2. Arrêt services Docker
3. Export ZFS : zfs send tank-hdd@migrate | zfs recv tank-new
4. Remplacement physique disque
5. Import pool : zpool import tank-new
6. Restart services

## Maintenance
- Scrub ZFS mensuel
- Prune Restic
- Reboot serveur (procédure)
```

**Action** : remplir avant de déployer en prod.

---

### 4. **Arborescence : redondances/manques**

#### ❌ Manque critique : **`/docs/ADR/004-zfs-vs-btrfs.md`**
Tu as le fichier dans tes uploads, mais il n'est pas listé dans le `README.md` des ADR.

#### ⚠️ Journal optionnel ?
```
docs/journal/2025-10-week43.md  # Entrées hebdo