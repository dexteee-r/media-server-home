# 🔒 Politique de sécurité — Projet *media-server-home*

## 📘 Contexte général

Le projet **media-server-home** est un **serveur multimédia auto-hébergé** (photos & vidéos), déployé sur un hôte **Proxmox VE 8** avec :
- une **VM-EXTRANET (Debian 12)** dédiée au proxy et VPN ;
- une **VM-INTRANET (Debian 12)** hébergeant les backends et données ;
- un **pool ZFS** sur l’hôte pour le stockage (`media`, `photos`, `appdata`, `backups`).

Les objectifs principaux :
1. Protéger les **données personnelles** et fichiers multimédias.  
2. Sécuriser l’accès aux services internes via une **DMZ (EXTRANET)**.  
3. Prévenir la perte de données grâce à des **sauvegardes chiffrées et testées**.  
4. Garantir un **accès distant privé et chiffré** via VPN (OpenVPN).

---

## 🧱 Architecture de sécurité

```

+-----------------------------+

| Proxmox VE                      |
| ------------------------------- |
| - ZFS (tank)                    |
| - Firewall Proxmox              |
| +-----------+-----------------+ |

```
        |
   Bridges réseau :
   vmbr0 → LAN (INTRANET)
   vmbr1 → DMZ (EXTRANET)
        |
```

+-------------------+      +-------------------+
| VM-INTRANET       |      | VM-EXTRANET       |
| Debian 12         |      | Debian 12         |
| - Jellyfin        |      | - Nginx Proxy Mgr |
| - Immich + DB     |<---->| - OpenVPN         |
| - Prometheus/Graf.|      | - node_exporter   |
| - Restic          |      |                   |
+-------------------+      +-------------------+

```

---

## 🔑 1. Gestion des accès et authentification

### Comptes système
- Accès SSH uniquement via **clé publique** (`~/.ssh/authorized_keys`).
- Port SSH personnalisé (≠ 22) et protégé par **Fail2ban**.
- Interdiction de connexion root (`PermitRootLogin no`).
- Utilisateur administrateur : `media-admin`.

### Services applicatifs
| Service | VM | Authentification | Protection |
|----------|----|------------------|-------------|
| **Nginx Proxy Manager** | EXTRANET | Interface web protégée (admin/password fort) | HTTPS + accès LAN/VPN |
| **Jellyfin** | INTRANET | Compte admin + comptes locaux | Accessible via proxy |
| **Immich** | INTRANET | Auth interne (email + mot de passe) | Non exposé directement |
| **Grafana** | INTRANET | Admin/password dans `.env`, changé au premier login | HTTPS via proxy |
| **Prometheus** | INTRANET | Aucune modif possible à distance | Accès LAN/VPN uniquement |

### VPN / Accès distant
- Accès distant via **OpenVPN** (hébergé sur la VM-EXTRANET).
- Chiffrement : **AES-256-CBC** + clé DH 4096 bits.  
- Les fichiers clients `.ovpn` sont générés manuellement et distribués de façon sécurisée.
- Aucun autre port public n’est exposé.

---

## 🧰 2. Réseau et isolation

| Élément | Sécurisation appliquée |
|----------|------------------------|
| **Bridge `vmbr0` (INTRANET)** | Réseau LAN privé, isolé de l’extérieur |
| **Bridge `vmbr1` (EXTRANET)** | Réseau DMZ pour NPM & VPN |
| **Proxmox Firewall** | Activé au niveau Datacenter + VM |
| **UFW (chaque VM)** | Politique `deny incoming` + autorisations spécifiques |
| **DNS interne** | `*.home.arpa` — non résolu à l’extérieur |

### 🔐 Segmentation réseau

| Zone | VM | Services | Rôle |
|------|----|-----------|------|
| **EXTRANET (DMZ)** | `vm-extranet` | NPM, OpenVPN | Point d’entrée unique |
| **INTRANET (LAN)** | `vm-intranet` | Jellyfin, Immich, Postgres, Grafana, Prometheus, Restic | Données et services internes |

### 🔁 Flux autorisés

| Source → Cible | Ports | Description |
|----------------|-------|-------------|
| **Clients LAN → EXTRANET** | 443/TCP, 1194/UDP | HTTPS + VPN |
| **EXTRANET → INTRANET** | 8096, 2283, 3001, 9090, 3000 | Proxy + supervision |
| **INTRANET → EXTRANET** | 443 (ACME certs), 9100 (metrics) | Sortants contrôlés |
| **INTRANET ↔ Internet** | Sortants uniquement | MàJ système & Docker |

---

## 🔒 3. Chiffrement et confidentialité

| Domaine | Mesure de sécurité |
|----------|--------------------|
| **Transport** | HTTPS (Let’s Encrypt via NPM) + VPN OpenVPN AES-256 |
| **Sauvegardes** | Restic AES-256 avant envoi sur disque ou NAS |
| **Stockage** | ZFS avec vérification d’intégrité + snapshots automatiques |
| **Secrets** | `.env` (non versionné) + `/etc/restic/passwd` (chmod 600) |
| **Accès distant** | Exclusivement via OpenVPN (aucun port public direct) |

---

## 🧩 4. Sauvegardes et restauration

### Multi-VM
- **INTRANET** → sauvegarde complète via Restic :
  - `/mnt/tank/media`, `/mnt/tank/photos`, `/mnt/tank/appdata`, `/mnt/tank/backups`
- **EXTRANET** → sauvegarde légère (NPM config, OpenVPN keys)
- **Priorité de restauration** :  
  1️⃣ EXTRANET (proxy + VPN)  
  2️⃣ INTRANET (services internes + données)

### Fréquence
| Type | Fréquence | Outil |
|------|------------|-------|
| Configs + bases de données | Quotidienne | Restic |
| Médias & photos | Hebdomadaire | Restic |
| Snapshots ZFS | Quotidien / Hebdomadaire | ZFS auto-snapshot |
| Tests de restauration | Mensuel | `restic restore` dans dataset test |

---

## 🧠 5. Mises à jour et durcissement

| Composant | Mesures |
|------------|----------|
| **Debian** | `apt upgrade` hebdomadaire, `unattended-upgrades` actif |
| **Docker / Compose** | MàJ via Watchtower |
| **Proxmox** | Firewall actif, accès root restreint |
| **Nginx Proxy Manager** | Certificats Let’s Encrypt auto-renouvelés |
| **OpenVPN** | Rotation mensuelle des certificats |
| **ZFS** | Scrub mensuel (`zpool scrub tank`) |
| **Restic** | Rotation automatique (`forget --prune`) |

---

## 🧩 6. Supervision et audit

| Élément | Contrôle |
|----------|----------|
| **Prometheus + Grafana** | Collecte métriques INTRANET + EXTRANET |
| **node_exporter (EXTRANET)** | Scrapé par Prometheus (port 9100) |
| **Logs NPM / VPN** | Centralisés et sauvegardés hebdomadairement |
| **Alertes** | Échec de backup → alerte Grafana |
| **Audit mensuel** | Vérification snapshots ZFS + restauration Restic |

---

## 🧾 7. Plan de réponse aux incidents

| Scénario | Action immédiate | Suivi |
|-----------|------------------|--------|
| Panne disque (ZFS) | Restaurer depuis Restic | Remplacer le disque, resync pool |
| Corruption config Docker | Restauration Restic + snapshot | Automatiser dump `appdata` |
| Compromission VM-EXTRANET | Isolation réseau + rotation certs + recréation VM | Réexécution Playbook NPM/OpenVPN |
| Crash INTRANET | Boot sur live + Restic restore | Tester images VM Proxmox |

---

## 🗝️ 8. Règles d’or de sécurité

✅ Ne jamais exposer directement Jellyfin ou Immich.  
✅ Passer uniquement via **Nginx Proxy Manager (HTTPS)** ou **VPN OpenVPN**.  
✅ Restaurer périodiquement les backups Restic.  
✅ Utiliser uniquement des **mots de passe forts** (> 12 caractères).  
✅ Vérifier régulièrement la validité des certificats et clés VPN.  
✅ Maintenir **au moins deux copies** de chaque sauvegarde (locale + externe).

---

## 🔮 Actions suivantes

- [ ] Vérifier les permissions sur `/mnt/tank/backups`.  
- [ ] Mettre à jour `/infra/proxmox/README.md` (firewall + bridges).  

---

🗓️ **Journal de bord — 03/11/2025**  
- Mise à jour : architecture multi-VM (Intranet / Extranet).  
- VPN : passage à **OpenVPN** (remplace Tailscale).  
- Proxy : **Nginx Proxy Manager** remplace Traefik.  
- Politique de flux inter-VM ajoutée.  
- Sauvegardes et supervision adaptées à la segmentation.
