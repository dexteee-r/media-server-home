# Security Policy

# 🔒 Politique de sécurité — Projet *media-server-home*

## 📘 Contexte général

Le projet **media-server-home** est un **serveur multimédia auto-hébergé** (photos & vidéos), déployé sur un hôte **Proxmox VE 8** avec :
- une **VM “Services” (Ubuntu Server 24.04)** ;
- des **conteneurs Docker** : Jellyfin, Immich, Traefik, Postgres, Prometheus, Grafana, Restic, etc. ;
- un **système de fichiers ZFS** (datasets `media`, `photos`, `appdata`, `backups`).

Les objectifs principaux de la sécurité sont :
1. Protéger les **données personnelles** et fichiers multimédias.  
2. Sécuriser l’accès à l’interface web et aux services.  
3. Prévenir les pertes de données via **sauvegardes chiffrées**.  
4. Garantir un **accès distant privé** et un **réseau interne isolé**.

---

## 🧱 Architecture de sécurité

```
+-------------------------+
| Proxmox VE (Hôte) |
| - ZFS (tank) |
| - Firewall Proxmox |
+-----------+-------------+
|
Bridge vmbr0
|
+--------------------+
| VM "Services" |
| Ubuntu 24.04 LTS |
| Docker + Compose |
+--------------------+
| traefik-net (LAN)
|_______________________
Jellyfin / Immich / Grafana
↳ HTTPS only (Traefik)
↳ Authentification
↳ Logs + monitoring

```

---


---

## 🔑 1. Gestion des accès et authentification

### Comptes système
- Accès SSH uniquement via **clé publique** (`~/.ssh/authorized_keys`).
- Port SSH personnalisé (≠ 22) et protégé par **Fail2ban**.
- Interdiction de connexion root directe (`PermitRootLogin no`).
- Utilisateur administrateur dédié (`media-admin`).

### Services applicatifs
| Service | Méthode d’authentification | Protection |
|----------|-----------------------------|-------------|
| **Traefik Dashboard** | BasicAuth (mot de passe fort, fichier `.htpasswd`) | HTTPS + accès LAN uniquement |
| **Jellyfin** | Compte admin + comptes utilisateurs | Mots de passe forts, gestion locale |
| **Immich** | Authentification interne (email + mot de passe) | Pas d’accès public direct |
| **Grafana** | Admin/password dans `.env`, changé à la première connexion | HTTPS obligatoire |

### VPN / Accès distant
- Utilisation de **Tailscale** pour un accès privé au réseau domestique :
  - Pas d’exposition de ports publics.  
  - Connexions chiffrées (WireGuard-based).  
  - Accès restreint aux membres autorisés du réseau Tailscale.

---

## 🧰 2. Réseau et isolation

| Élément | Sécurisation appliquée |
|----------|------------------------|
| **Bridge `vmbr0` (Proxmox)** | Réseau LAN interne, pas de passerelle vers Internet par défaut |
| **VM “Services”** | Pare-feu Ubuntu activé (`ufw allow 22,80,443`), logs activés |
| **Réseau Docker** | `traefik-net` : bridge isolé pour les services web |
| **Traefik** | Reverse proxy unique, HTTPS sur tout le trafic interne |
| **Ports exposés** | 22 (SSH, restreint), 80/443 (Traefik), 9100 (Prometheus exporter, LAN only) |
| **DNS interne** | `*.home.arpa` — noms internes non résolus à l’extérieur |

---

## 🔒 3. Chiffrement et confidentialité

| Domaine | Mesure de sécurité |
|----------|--------------------|
| **Transport** | HTTPS obligatoire (certificats Let’s Encrypt ou self-signed via Traefik). |
| **Sauvegardes** | Chiffrement AES-256 via **Restic** avant écriture sur disque ou NAS. |
| **Repos (at rest)** | ZFS utilisé avec intégrité et auto-réparation. |
| **Accès distant** | Tunnel VPN chiffré (Tailscale). |
| **Mots de passe & secrets** | Stockés dans `.env` (jamais commités) + `/etc/restic/passwd` (chmod 600). |

---

## 🧩 4. Sauvegardes et restauration sécurisée

### Sauvegarde
- Outil : **Restic** (`ADR-005`).
- Répertoires protégés :
  - `/mnt/tank/appdata` → configurations des services.
  - `/mnt/tank/media` → fichiers vidéos.
  - `/mnt/tank/photos` → bibliothèques Immich.
- Sauvegarde locale : `/mnt/tank/backups/restic-repo/`.
- Sauvegarde externe : disque USB (monté ponctuellement) ou NAS distant via `sftp`.
- Fréquence :
  - Quotidienne pour `appdata` et bases de données.
  - Hebdomadaire pour `media` et `photos`.

### Restauration
- Tests mensuels de restauration dans un dataset temporaire `tank/test-restore`.
- Commandes documentées dans `/docs/OPERATIONS.md`.

---

## 🧠 5. Mises à jour et durcissement

### Mises à jour
- **Watchtower** pour mise à jour automatique des conteneurs Docker.
- Mises à jour système via `apt upgrade` hebdomadaire.
- Vérification mensuelle des images obsolètes (`docker image prune -a`).

### Durcissement
| Composant | Mesures appliquées |
|------------|--------------------|
| **Ubuntu** | UFW, fail2ban, désactivation SSH root |
| **Docker** | Userspace rootless non nécessaire (réseau interne isolé) |
| **Proxmox** | Mises à jour régulières, utilisateurs limités, backups chiffrés |
| **Traefik** | HTTPS enforced, middlewares Security Headers + Rate Limit |
| **ZFS** | Snapshots automatiques (quotidiens/hebdomadaires) |
| **Restic** | Suppression automatique des anciennes sauvegardes (`forget --prune`) |

---

## 🧩 6. Supervision et audit

| Élément | Contrôle appliqué |
|----------|------------------|
| **Prometheus + Grafana** | Surveille CPU, RAM, stockage, réseau, Restic |
| **Alertes Restic** | Échec de backup → alerte Grafana ou e-mail |
| **Logs centralisés** | `/var/log/docker/` + `Promtail` (future extension) |
| **Audit mensuel** | Vérification des snapshots, taille disques, journaux |

---

## 🧾 7. Plan de réponse aux incidents

| Scénario | Mesure immédiate | Action à long terme |
|-----------|------------------|----------------------|
| Panne disque | Restaurer depuis sauvegarde Restic | Remplacer le disque et reconstruire le pool ZFS |
| Corruption de config Docker | Restaurer `/appdata` depuis snapshot ZFS | Automatiser sauvegarde quotidienne |
| Compromission compte admin | Révocation SSH key + rotation des mots de passe | Activation MFA via Tailscale |
| Crash système | Boot sur live USB + restauration Restic | Tester images VM sur Proxmox Backup |

---

## 🗝️ 8. Règles d’or de sécurité (résumé)

✅ Ne jamais exposer Jellyfin ou Immich directement sur Internet.  
✅ Toujours passer par **Traefik HTTPS** ou **VPN Tailscale**.  
✅ Vérifier mensuellement la restauration Restic.  
✅ Utiliser uniquement des **mots de passe forts** (> 12 caractères, alphanumériques + symboles).  
✅ Mettre à jour les conteneurs régulièrement (Watchtower).  
✅ Conserver au moins **2 copies de chaque sauvegarde** (locale + externe).

---

## 🔮 Actions suivantes

- [ ] Documenter la création du réseau Tailscale dans `/infra/vm/services-ubuntu.md`.  
- [ ] Ajouter un tableau “Ports ouverts & justification” dans `/docs/ARCHITECTURE.md`.  
- [ ] Vérifier les permissions du dossier `/mnt/tank/backups`.  
- [ ] Mettre à jour `/scripts/healthcheck.sh` pour vérifier l’état des sauvegardes et certificats.  

---

🗓️ **Journal de bord Future desicion** 
- Document : *SECURITY.md* finalisé.  
- Couverture : accès, VPN, chiffrement, sauvegardes, durcissement.  
- Étape suivante : finaliser **ARCHITECTURE.md** (schéma global + flux réseau + ports exposés).



💡 Résumé pour ton Wiki

Politique de sécurité (SECURITY.md)
SSH par clé, accès admin restreint
HTTPS obligatoire (Traefik)
Sauvegardes chiffrées (Restic AES-256)
Accès distant via Tailscale uniquement
Snapshots ZFS automatiques + audit mensuel