# ADR-008 — Architecture multi-VM : EXTRANET + INTRANET

## 📘 Contexte

**Date décision :** 02/11/2025

Initialement prévu : **1 VM Ubuntu 24.04 "Services"** monolithique.

**Problèmes identifiés :**
- Surface d'attaque élevée (services publics + données critiques mélangés)
- Compromission d'un service = accès à tout
- Backup/restore non granulaire
- Complexité gestion sécurité (tout dans une VM)

---

## 🧩 Options étudiées

| Option | Architecture | Avantages | Inconvénients |
|--------|--------------|-----------|---------------|
| **A - 1 VM monolithique** | Tous services dans 1 VM | Simple, moins de RAM | Surface d'attaque max |
| **B - 2 VMs (DMZ + LAN)** | EXTRANET + INTRANET | Isolation forte, sécurité | RAM x2, routing |
| **C - 1 VM + Docker networks** | Isolation par conteneurs | Léger | Isolation faible |

---

## ✅ Décision finale

> **Adopté : Option B — 2 VMs (EXTRANET + INTRANET)**

### **Architecture retenue**

```
Proxmox VE 8.4 (1 interface physique)
└─ vmbr0 (192.168.1.0/24) — Bridge unique
   ├─ VM-EXTRANET (192.168.1.100)
   │  ├─ Debian 13
   │  ├─ 4 GB RAM, 2 vCPU
   │  ├─ Exposition Internet (80/443/1194)
   │  └─ Services : NPM, OpenVPN, Fail2ban
   │
   └─ VM-INTRANET (192.168.1.101)
      ├─ Debian 13
      ├─ 12 GB RAM, 3 vCPU
      ├─ AUCUNE exposition directe Internet
      └─ Services : Jellyfin, Immich, Postgres, 
                    Prometheus, Grafana, Restic
```

---

## 🎯 Répartition des rôles

### **VM-EXTRANET (192.168.1.100) — "Porte d'entrée"**

**Rôle :** Point d'entrée unique depuis Internet

**Services hébergés :**
- **Nginx Proxy Manager (NPM)** → Reverse proxy HTTPS
  - Ports : 80/tcp, 443/tcp
  - Redirige vers services INTRANET
  - Certificats Let's Encrypt (elmzn.be)
  
- **OpenVPN** → Accès distant sécurisé
  - Port : 1194/udp
  - Tunnel chiffré vers LAN complet
  
- **ddclient** → DNS dynamique OVH
  - Update IP publique → elmzn.be
  
- **Fail2ban** → Protection bruteforce
  - Surveille logs NPM + SSH
  - Bannissement automatique IP malveillantes
  
- **UFW** → Firewall VM
  - Allow 80/443/1194 depuis Internet
  - Allow communication avec VM-INTRANET
  - Deny tout le reste

**Exposition Internet :**
```
Box Internet (port forwarding) :
  80/tcp → 192.168.1.100:80
  443/tcp → 192.168.1.100:443
  1194/udp → 192.168.1.100:1194
```

---

### **VM-INTRANET (192.168.1.101) — "Services métier"**

**Rôle :** Héberge applications sans exposition directe

**Services hébergés :**
- **Jellyfin** (:8096) → Streaming vidéo/musique
- **Immich** (:2283) → Gestion photos
- **Postgres** (:5432) → Base de données Immich
- **Prometheus** (:9090) → Métriques système
- **Grafana** (:3000) → Dashboards monitoring
- **Restic** → Backups chiffrés (Postgres + médias)

**Exposition Internet :**
```
AUCUN port exposé directement ✅

Accès uniquement via :
  1. NPM (VM-EXTRANET) → reverse proxy
  2. OpenVPN → tunnel LAN
  3. Réseau LAN local (192.168.1.x)
```

**UFW (firewall) :**
```bash
# Autoriser UNIQUEMENT VM-EXTRANET (NPM)
ufw allow from 192.168.1.100 to any port 8096,2283,9090,3000

# Autoriser accès LAN (famille)
ufw allow from 192.168.1.0/24 to any port 8096,2283,3000

# SSH depuis LAN uniquement
ufw allow from 192.168.1.0/24 to any port 22

# BLOQUER accès direct Internet
ufw default deny incoming
```

---

## 🌐 Flux d'accès

### **Cas 1 : Internet → Jellyfin**

```
Navigateur (4G/externe)
    ↓
https://jellyfin.elmzn.be
    ↓
DNS OVH → IP publique box
    ↓
Box (port 443 forwarding)
    ↓
VM-EXTRANET:443 (NPM)
    ↓ (reverse proxy interne)
VM-INTRANET:8096 (Jellyfin)
```

---

### **Cas 2 : LAN → Jellyfin (optimisé)**

```
TV/PC LAN (192.168.1.x)
    ↓
http://192.168.1.101:8096 (direct)
    OU
https://jellyfin.elmzn.be (via NPM, si split DNS)
```

**Optimisation recommandée : Split DNS**
- Pi-hole / AdGuard Home
- `jellyfin.elmzn.be` → 192.168.1.101 (LAN)
- Bypass NPM en interne = gain latence

---

### **Cas 3 : VPN → Tout le réseau**

```
Laptop distant
    ↓
OpenVPN client (.ovpn)
    ↓
vpn.elmzn.be:1194 (VM-EXTRANET)
    ↓
Tunnel 10.8.0.x créé
    ↓
Accès direct à :
  - 192.168.1.100:8006 (Proxmox web)
  - 192.168.1.101:8096 (Jellyfin)
  - 192.168.1.101:3000 (Grafana)
  - Tout le LAN 192.168.1.0/24
```

---

## 🔒 Sécurité (Defense in Depth)

### **Couche 1 : Box Internet**
- Firewall box (ports 80/443/1194 UNIQUEMENT)
- NAT vers VM-EXTRANET
- Tous autres ports : fermés

### **Couche 2 : Proxmox Firewall (optionnel)**
- Datacenter level : règles globales
- VM level : limiter ports par VM
- Node level : protéger hôte Proxmox

### **Couche 3 : VM-EXTRANET (UFW + Fail2ban)**
- UFW : allow 80/443/1194, deny reste
- Fail2ban : bannit bruteforce SSH/HTTP
- Logs centralisés

### **Couche 4 : VM-INTRANET (UFW strict)**
- Allow UNIQUEMENT depuis 192.168.1.100
- Allow LAN (192.168.1.0/24)
- Deny Internet direct
- Isolation maximum

### **Couche 5 : Application**
- Jellyfin : authentification utilisateur
- Immich : authentification utilisateur
- Grafana : admin password
- Postgres : credentials .env

---

## 🔁 Conséquences & impacts

### **Avantages**

| Aspect | Impact |
|--------|--------|
| **Sécurité** | Surface d'attaque réduite (INTRANET jamais exposé) |
| **Résilience** | Compromission EXTRANET ≠ accès INTRANET |
| **Backup** | Granulaire (VM-INTRANET seule = données critiques) |
| **Maintenance** | Update EXTRANET sans toucher services métier |
| **Monitoring** | Logs séparés par VM (audit facilité) |
| **Évolutivité** | Ajout services publics futurs (VM-EXTRANET) |

### **Inconvénients**

| Aspect | Impact | Mitigation |
|--------|--------|------------|
| **RAM** | 16 GB nécessaire (vs 8 GB pour 1 VM) | ✅ Upgrade fait |
| **Complexité** | Gestion 2 VMs + réseau | ✅ Doc complète |
| **Latence** | +5-10ms (hop NPM) | ⚠️ Négligeable usage domestique |

---

## 📊 Ressources allouées

### **VM-EXTRANET (100)**
```
RAM : 4 GB
vCPU : 2 cores
Disque : 20 GB (SSD)
Réseau : vmbr0 (192.168.1.100)
```

### **VM-INTRANET (101)**
```
RAM : 12 GB
vCPU : 3 cores
Disque : 40 GB (SSD)
Réseau : vmbr0 (192.168.1.101)
GPU : Intel HD 530 passthrough (transcodage Jellyfin)
```

**Total utilisé : 16 GB RAM, 5 vCPU (1 core libre pour Proxmox)**

---

## 🧪 Tests de validation

### **Test 1 : Isolation réseau**
```bash
# Depuis VM-INTRANET, tenter accès direct Internet
curl -I https://google.com
# ✅ Doit fonctionner (outgoing autorisé)

# Depuis Internet, scanner VM-INTRANET
nmap 192.168.1.101 -p 8096
# ✅ Doit échouer (UFW bloque)
```

### **Test 2 : Reverse proxy fonctionnel**
```bash
# Depuis Internet (4G)
curl -I https://jellyfin.elmzn.be
# ✅ Doit retourner 200 OK (via NPM)
```

### **Test 3 : VPN accès complet**
```bash
# Connecté au VPN
curl http://192.168.1.101:3000
# ✅ Doit afficher Grafana
```

---

## 🔮 Évolutions futures

### **Court terme (optionnel)**
- [ ] Split DNS (Pi-hole LXC)
- [ ] WAF devant NPM (ModSecurity)
- [ ] Cloudflare Tunnel (alternative OpenVPN)

### **Moyen terme**
- [ ] VM-BACKUP dédiée (Proxmox Backup Server)
- [ ] VM-MONITORING (stack complète Loki + Promtail)

### **Long terme**
- [ ] Cluster Proxmox (si 2ème machine)
- [ ] HA services critiques (Postgres replica)

---

## 📝 Notes complémentaires

### **Pourquoi pas vmbr1 (bridge DMZ séparé) ?**

**Décision :** Tout en vmbr0 (1 seul bridge)

**Raisons :**
- 1 seule interface physique (pas de VLAN tagging)
- Isolation suffisante via UFW (firewall VM)
- Moins de complexité routing inter-bridges
- Homelab domestique (pas de conformité réglementaire)

**Si besoin futur :**
- Créer vmbr1 (bridge interne)
- VM-EXTRANET : 2 interfaces (vmbr0 + vmbr1)
- VM-INTRANET : 1 interface (vmbr1 uniquement)
- Proxmox : router/firewall entre bridges

---

🗓️ **Date :** 02/11/2025  
**Statut :** ✅ Adopté et déployé  
**Révision prévue :** 6 mois (évaluation performances/sécurité)