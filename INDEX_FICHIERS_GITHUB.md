# 📦 INDEX DES FICHIERS GÉNÉRÉS - MISE À JOUR GITHUB

Date de génération : 2025-11-28  
Architecture : Version 2.0 (Dual-Machine EXTRANET/INTRANET)

---

## 📂 STRUCTURE FINALE DU REPO

```
media-server-home/
├─ README.md                          ⭐ NOUVEAU (architecture 2 machines)
├─ CHANGELOG.md                       ⭐ NOUVEAU (historique versions)
├─ LICENSE                            ✅ (existant - MIT)
├─ .gitignore                         ✅ (existant)
├─ .env.example                       ⭐ NOUVEAU (template variables)
│
├─ docs/
│  ├─ ARCHITECTURE.md                 ✏️ À METTRE À JOUR
│  ├─ SETUP-MACHINE1.md              ⭐ NOUVEAU (guide M1 EXTRANET)
│  ├─ SETUP-MACHINE2.md              ⭐ NOUVEAU (guide M2 INTRANET)
│  ├─ MIGRATION-GUIDE.md             ⭐ NOUVEAU (migration 1→2 machines)
│  ├─ OPERATIONS.md                   ✏️ À METTRE À JOUR
│  ├─ SECURITY.md                     ✏️ À METTRE À JOUR
│  └─ ADR/
│     ├─ README.md                    ✅ (existant)
│     ├─ 001-010-*.md                 ✅ (existants)
│     └─ 011-architecture-2-machines.md  ⭐ NOUVEAU
│
├─ configs/
│  ├─ machine1-extranet/              ⭐ NOUVEAU DOSSIER
│  │  └─ docker-compose.yml           ⭐ (stack EXTRANET)
│  └─ machine2-intranet/              ⭐ NOUVEAU DOSSIER
│     └─ docker-compose.yml           ⭐ (stack INTRANET)
│
├─ scripts/
│  ├─ backup-m2-to-m1.sh             ⭐ NOUVEAU (backup automatisé)
│  ├─ setup-machine1.sh              📝 (à créer - optionnel)
│  └─ setup-machine2.sh              📝 (à créer - optionnel)
│
└─ assets/                            📝 (optionnel - screenshots)
   └─ architecture-diagram.png
```

**Légende :**
- ⭐ NOUVEAU : Fichier créé pour cette version
- ✏️ À METTRE À JOUR : Fichier existant nécessitant modifications
- ✅ EXISTANT : Fichier déjà présent, pas de changement
- 📝 OPTIONNEL : Fichier suggéré, pas obligatoire

---

## 📥 FICHIERS TÉLÉCHARGEABLES

### **1. Documents Principaux**

#### README.md (⭐ Priorité 1)
**Chemin destination :** `./README.md`  
**Description :** Vue d'ensemble complète architecture 2 machines  
**Taille :** ~10 KB  
**Contient :**
- Architecture overview avec schéma
- Specs matérielles Machine #1 et #2
- Services déployés
- Quick start
- Liens documentation

📥 **[Télécharger README.md](computer:///home/claude/README.md)**

---

#### CHANGELOG.md (⭐ Priorité 1)
**Chemin destination :** `./CHANGELOG.md`  
**Description :** Historique des versions (1.0 → 2.0)  
**Taille :** ~6 KB  
**Contient :**
- Version 2.0.0 : Architecture 2 machines
- Version 1.x : Historique ancien
- Roadmap futur (v2.1, v2.2, v3.0)

📥 **[Télécharger CHANGELOG.md](computer:///home/claude/CHANGELOG.md)**

---

### **2. Architecture Decision Records (ADR)**

#### ADR-011-architecture-2-machines.md (⭐ Priorité 1)
**Chemin destination :** `./docs/ADR/011-architecture-2-machines.md`  
**Description :** Décision technique architecture 2 machines  
**Taille :** ~8 KB  
**Contient :**
- Contexte décision
- Justifications (sécurité, performance, apprentissage)
- Alternatives considérées
- Conséquences et métriques

📥 **[Télécharger ADR-011](computer:///home/claude/ADR-011-architecture-2-machines.md)**

---

### **3. Configuration Docker Compose**

#### docker-compose-machine1-extranet.yml (⭐ Priorité 1)
**Chemin destination :** `./configs/machine1-extranet/docker-compose.yml`  
**Description :** Stack services EXTRANET (DMZ)  
**Taille :** ~5 KB  
**Services :**
- Nginx Proxy Manager
- Node Exporter
- Uptime Kuma (monitoring)
- Fail2ban (optionnel)

📥 **[Télécharger docker-compose M1](computer:///home/claude/docker-compose-machine1-extranet.yml)**

---

#### docker-compose-machine2-intranet.yml (⭐ Priorité 1)
**Chemin destination :** `./configs/machine2-intranet/docker-compose.yml`  
**Description :** Stack services INTRANET (stockage + apps)  
**Taille :** ~8 KB  
**Services :**
- Immich (photos)
- Nextcloud (fichiers)
- PostgreSQL + Redis
- Prometheus + Grafana
- Node Exporter

📥 **[Télécharger docker-compose M2](computer:///home/claude/docker-compose-machine2-intranet.yml)**

---

### **4. Variables Environnement**

#### .env.example (⭐ Priorité 1)
**Chemin destination :** `./.env.example`  
**Description :** Template variables avec instructions  
**Taille :** ~3 KB  
**Contient :**
- Passwords PostgreSQL, Redis, Grafana
- Configuration Restic backups
- Network configuration
- Exemples génération passwords sécurisés

📥 **[Télécharger .env.example](computer:///home/claude/.env.example)**

---

### **5. Scripts Automatisation**

#### backup-m2-to-m1.sh (⭐ Priorité 1)
**Chemin destination :** `./scripts/backup-m2-to-m1.sh`  
**Description :** Backup automatisé Restic (M2 → M1)  
**Taille :** ~8 KB  
**Fonctionnalités :**
- Backup PostgreSQL (dump SQL)
- Backup configs Docker
- Backup photos Immich (4 TB)
- Backup fichiers Nextcloud
- Pruning automatique (7 daily, 4 weekly, 6 monthly)
- Logging + notifications (optionnel webhook)

📥 **[Télécharger backup-m2-to-m1.sh](computer:///home/claude/backup-m2-to-m1.sh)**

⚠️ **Après téléchargement :** `chmod +x scripts/backup-m2-to-m1.sh`

---

### **6. Guides Installation (Optionnel mais Recommandé)**

#### GUIDE_INSTALL_MACHINE2_INTRANET.md
**Chemin destination :** `./docs/SETUP-MACHINE2.md`  
**Description :** Guide complet installation Machine #2  
**Taille :** ~11 KB  
**Étapes :**
1. Installation matérielle (HDD 4 TB)
2. Installation Proxmox VE 8.4
3. Configuration ZFS + NFS
4. Création VM-INTRANET + services
5. Création VMs laboratoire
6. Validation finale

📥 **[Télécharger Guide M2](computer:///home/claude/GUIDE_INSTALL_MACHINE2_INTRANET.md)**

---

#### GUIDE_CONFIG_MACHINE1_EXTRANET.md
**Chemin destination :** `./docs/SETUP-MACHINE1.md`  
**Description :** Guide reconfiguration Machine #1  
**Taille :** ~8 KB  
**Étapes :**
1. Audit configuration actuelle
2. Migration services INTRANET → M2
3. Reconfiguration EXTRANET pure
4. Configuration reverse proxy NPM
5. Tests communication M1 ↔ M2
6. Setup backups M2 → M1

📥 **[Télécharger Guide M1](computer:///home/claude/GUIDE_CONFIG_MACHINE1_EXTRANET.md)**

---

### **7. Guide Mise à Jour GitHub**

#### GUIDE_GITHUB_UPDATE.md
**Description :** Instructions complètes pour push GitHub  
**Taille :** ~8 KB  
**Contient :**
- Commandes Git étape par étape
- Checklist pré-push
- Messages commit suggérés
- Troubleshooting

📥 **[Télécharger Guide GitHub](computer:///home/claude/GUIDE_GITHUB_UPDATE.md)**

---

## 🚀 WORKFLOW RECOMMANDÉ

### **Étape 1 : Télécharger Fichiers Essentiels**

Télécharge dans l'ordre de priorité :

1. ⭐ `README.md`
2. ⭐ `CHANGELOG.md`
3. ⭐ `ADR-011-architecture-2-machines.md`
4. ⭐ `docker-compose-machine1-extranet.yml`
5. ⭐ `docker-compose-machine2-intranet.yml`
6. ⭐ `.env.example`
7. ⭐ `backup-m2-to-m1.sh`

### **Étape 2 : Organiser dans Repo Local**

```bash
cd ~/media-server-home

# Créer structure dossiers
mkdir -p configs/machine1-extranet
mkdir -p configs/machine2-intranet
mkdir -p docs/ADR
mkdir -p scripts

# Copier fichiers téléchargés
cp ~/Downloads/README.md ./
cp ~/Downloads/CHANGELOG.md ./
cp ~/Downloads/ADR-011-*.md ./docs/ADR/
cp ~/Downloads/docker-compose-machine1-extranet.yml ./configs/machine1-extranet/docker-compose.yml
cp ~/Downloads/docker-compose-machine2-intranet.yml ./configs/machine2-intranet/docker-compose.yml
cp ~/Downloads/.env.example ./
cp ~/Downloads/backup-m2-to-m1.sh ./scripts/
chmod +x ./scripts/backup-m2-to-m1.sh

# Optionnel : guides installation
cp ~/Downloads/GUIDE_INSTALL_MACHINE2_INTRANET.md ./docs/SETUP-MACHINE2.md
cp ~/Downloads/GUIDE_CONFIG_MACHINE1_EXTRANET.md ./docs/SETUP-MACHINE1.md
```

### **Étape 3 : Commit & Push**

```bash
git add .
git commit -m "feat: migrate to 2-machine architecture (v2.0.0)"
git push origin main
```

Voir guide détaillé : [GUIDE_GITHUB_UPDATE.md](computer:///home/claude/GUIDE_GITHUB_UPDATE.md)

---

## ✅ CHECKLIST FINALE

Avant de push, vérifie :

### Fichiers Obligatoires
- [ ] `README.md` copié et à jour
- [ ] `CHANGELOG.md` ajouté
- [ ] `docs/ADR/011-architecture-2-machines.md` ajouté
- [ ] `configs/machine1-extranet/docker-compose.yml` créé
- [ ] `configs/machine2-intranet/docker-compose.yml` créé
- [ ] `.env.example` créé
- [ ] `scripts/backup-m2-to-m1.sh` exécutable

### Fichiers Sensibles Protégés
- [ ] `.gitignore` contient `.env`
- [ ] Aucun password en clair dans repo
- [ ] Aucun fichier volumineux (>100 MB)

### Documentation Cohérente
- [ ] Liens internes README fonctionnels
- [ ] Badges à jour (si présents)
- [ ] Structure dossiers respectée

### Tests Syntaxe
- [ ] `docker-compose config` OK sur les 2 stacks
- [ ] `bash -n backup-m2-to-m1.sh` OK
- [ ] Markdown valide (markdownlint optionnel)

---

## 📞 SUPPORT

Si problème durant mise à jour :

1. **Consulter :** [GUIDE_GITHUB_UPDATE.md](computer:///home/claude/GUIDE_GITHUB_UPDATE.md)
2. **Troubleshooting :** Section dédiée dans guide
3. **GitHub Issues :** Créer issue si blocage

---

## 🎯 PROCHAINES ÉTAPES

Après push GitHub :

1. ✅ Vérifier rendu sur https://github.com/TON_USER/media-server-home
2. 📸 Ajouter screenshots (optionnel)
3. 🏷️ Créer release v2.0.0 (optionnel)
4. 📢 Partager sur r/selfhosted (optionnel)
5. 🚀 Implémenter physiquement architecture

---

**Tout est prêt pour la mise à jour ! 🎉**

Temps estimé : **30 minutes** (téléchargement + organisation + push)
