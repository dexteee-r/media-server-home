# 📤 GUIDE MISE À JOUR REPO GITHUB

## Fichiers Créés/Modifiés

### ✅ **Documents Principaux**
- [x] `README.md` - Vue d'ensemble architecture 2 machines
- [x] `docs/ADR/011-architecture-2-machines.md` - ADR décision architecture
- [x] `configs/machine1-extranet/docker-compose.yml` - Stack EXTRANET
- [x] `configs/machine2-intranet/docker-compose.yml` - Stack INTRANET
- [x] `.env.example` - Template variables environnement
- [x] `scripts/backup-m2-to-m1.sh` - Script backup automatisé

### 📋 **À Créer Manuellement**
Ces fichiers nécessitent adaptations spécifiques (tu les as déjà en local) :
- [ ] `docs/ARCHITECTURE.md` - Schémas Mermaid détaillés
- [ ] `docs/SETUP-MACHINE1.md` - Guide installation M1
- [ ] `docs/SETUP-MACHINE2.md` - Guide installation M2
- [ ] `docs/MIGRATION-GUIDE.md` - Guide migration 1→2 machines
- [ ] `docs/OPERATIONS.md` - Runbooks opérations
- [ ] `docs/SECURITY.md` - Politique sécurité

---

## 🚀 Commandes Git

### **1. Préparer le Repo Local**

```bash
# Naviguer vers ton repo local
cd ~/media-server-home

# Vérifier branche actuelle
git branch
# Si pas sur 'main' :
git checkout main

# Vérifier status
git status
```

### **2. Copier Fichiers Générés**

```bash
# Créer structure dossiers si nécessaire
mkdir -p configs/machine1-extranet
mkdir -p configs/machine2-intranet
mkdir -p docs/ADR
mkdir -p scripts

# Copier fichiers depuis /home/claude/ (où je les ai générés)
# Tu devras adapter les chemins selon où tu as téléchargé les fichiers

# README principal
cp ~/Downloads/README.md ./README.md

# ADR
cp ~/Downloads/ADR-011-architecture-2-machines.md ./docs/ADR/011-architecture-2-machines.md

# Docker Compose
cp ~/Downloads/docker-compose-machine1-extranet.yml ./configs/machine1-extranet/docker-compose.yml
cp ~/Downloads/docker-compose-machine2-intranet.yml ./configs/machine2-intranet/docker-compose.yml

# Variables environnement
cp ~/Downloads/.env.example ./.env.example

# Scripts
cp ~/Downloads/backup-m2-to-m1.sh ./scripts/backup-m2-to-m1.sh
chmod +x ./scripts/backup-m2-to-m1.sh

# Guides installation (si créés)
# cp ~/Downloads/GUIDE_INSTALL_MACHINE2_INTRANET.md ./docs/SETUP-MACHINE2.md
# cp ~/Downloads/GUIDE_CONFIG_MACHINE1_EXTRANET.md ./docs/SETUP-MACHINE1.md
```

### **3. Vérifier Modifications**

```bash
# Voir fichiers modifiés
git status

# Voir différences (optionnel)
git diff README.md
git diff docs/ADR/011-architecture-2-machines.md
```

### **4. Commit Changements**

```bash
# Ajouter tous les fichiers nouveaux/modifiés
git add .

# Ou ajouter sélectivement
git add README.md
git add docs/ADR/011-architecture-2-machines.md
git add configs/
git add scripts/
git add .env.example

# Vérifier ce qui sera commité
git status

# Créer commit avec message descriptif
git commit -m "feat: migrate to 2-machine architecture (EXTRANET/INTRANET)

- Add comprehensive README for dual-machine setup
- Add ADR-011: architecture decision for physical separation
- Add docker-compose for Machine #1 (EXTRANET DMZ)
- Add docker-compose for Machine #2 (INTRANET storage + VMs)
- Add automated backup script (Restic M2->M1)
- Add .env.example template for all services
- Update documentation with security best practices

Breaking changes:
- Architecture now requires 2 physical machines
- Services separated: EXTRANET (M1) / INTRANET (M2)
- New IP addressing: 192.168.1.111 (M1), 192.168.1.101 (M2)

Migration guide: docs/MIGRATION-GUIDE.md (to be added)
"
```

### **5. Push vers GitHub**

```bash
# Push vers branche main
git push origin main

# Vérifier sur GitHub
# https://github.com/TON_USER/media-server-home
```

---

## 📝 **Message Commit Détaillé (Optionnel)**

Si tu veux un commit encore plus descriptif :

```bash
git commit -m "feat: architecture 2.0 - dual-machine EXTRANET/INTRANET separation

ARCHITECTURE CHANGES:
- Migrate from 1-machine to 2-machine physical setup
- Machine #1 (Dell OptiPlex i5-6500): EXTRANET DMZ role
  * Nginx Proxy Manager (reverse proxy)
  * OpenVPN (remote access)
  * Fail2ban (security)
  * Node exporter (monitoring)
  
- Machine #2 (Custom i7-6700 + GTX 980): INTRANET storage + lab
  * Immich (4TB photos storage)
  * Nextcloud (file sharing)
  * PostgreSQL + Redis
  * Prometheus + Grafana
  * VM-DEV-LINUX + VM-DEV-WINDOWS

SECURITY IMPROVEMENTS:
- Defense in depth: 6-layer security model
- Machine #2 NEVER exposed directly to Internet
- Firewall isolation (UFW on both machines)
- Automated backups M2 → M1 (Restic encrypted)

DOCUMENTATION:
- ADR-011: Architecture decision with justification
- Docker Compose stacks for both machines
- .env.example with all required variables
- Backup automation script with logging

TECHNICAL SPECS:
- Proxmox VE 8.4 on both machines
- Debian 13 guest OS
- ZFS storage (4TB on M2)
- Docker Compose orchestration

TIMELINE: 2 weekends (~10h total setup time)
COST: ~110€ (4TB NAS HDD), +10€/month electricity

References:
- docs/ADR/011-architecture-2-machines.md
- configs/machine1-extranet/docker-compose.yml
- configs/machine2-intranet/docker-compose.yml
- scripts/backup-m2-to-m1.sh
"
```

---

## 🎯 **Checklist Finale Avant Push**

Assure-toi que :

### Fichiers Sensibles Protégés
```bash
# Vérifier .gitignore contient :
cat .gitignore

# Doit inclure :
.env
*.log
secrets/
*.key
*.pem
```

### README Cohérent
- [ ] Badges à jour (si tu en as)
- [ ] Liens documentation fonctionnels
- [ ] Screenshots (optionnel, à ajouter plus tard)
- [ ] Informations contact/license OK

### Documentation Complète
- [ ] ADR-011 présent dans `docs/ADR/`
- [ ] Guides installation (si créés)
- [ ] Docker Compose commentés
- [ ] Scripts exécutables (`chmod +x`)

### Tests Locaux
```bash
# Tester Docker Compose syntaxe
cd configs/machine1-extranet
docker-compose config  # Doit retourner config valide

cd ../machine2-intranet
docker-compose config  # Doit retourner config valide

# Tester script backup
bash -n scripts/backup-m2-to-m1.sh  # Check syntax
```

---

## 📊 **Après le Push**

### Vérifier sur GitHub
1. Va sur https://github.com/TON_USER/media-server-home
2. Vérifie que README s'affiche correctement
3. Vérifie structure dossiers :
   ```
   media-server-home/
   ├─ README.md (mise à jour visible)
   ├─ docs/ADR/011-*.md (nouveau)
   ├─ configs/machine1-extranet/ (nouveau)
   ├─ configs/machine2-intranet/ (nouveau)
   └─ scripts/backup-*.sh (nouveau)
   ```

### Créer Release (Optionnel)
```bash
# Créer tag version
git tag -a v2.0.0 -m "Release v2.0.0 - Dual-machine architecture"
git push origin v2.0.0

# Sur GitHub : Create Release from tag
# - Version : v2.0.0
# - Title : "Architecture 2.0 - EXTRANET/INTRANET Separation"
# - Description : Highlights from commit message
```

### Mettre à Jour Project Board (Si tu en as un)
- Déplacer tâches "Architecture 2 machines" en "Done"
- Créer nouvelles tâches :
  - [ ] Implémentation physique M2
  - [ ] Migration données M1→M2
  - [ ] Tests end-to-end
  - [ ] Screenshots documentation

---

## 🐛 **Troubleshooting**

### Erreur : "Remote contains work that you don't have locally"
```bash
# Pull les changements distants avant push
git pull --rebase origin main
git push origin main
```

### Erreur : "Fichier trop gros" (>100 MB)
```bash
# GitHub limite 100 MB par fichier
# Si fichiers volumineux (ISO, backups) :
git rm --cached chemin/vers/gros-fichier
echo "chemin/vers/gros-fichier" >> .gitignore
git commit --amend
```

### Conflit de merge
```bash
# Résoudre conflit manuellement dans éditeur
nano FICHIER_EN_CONFLIT

# Après résolution
git add FICHIER_EN_CONFLIT
git commit
git push origin main
```

---

## ✅ **Commandes Résumées**

```bash
# Quick push (si tout est prêt)
cd ~/media-server-home
git add .
git commit -m "feat: migrate to 2-machine architecture"
git push origin main

# Vérifier sur GitHub
# https://github.com/TON_USER/media-server-home
```

---

**Tu es prêt à push ! 🚀**

Une fois fait, ton repo GitHub sera à jour avec la nouvelle architecture 2 machines complètement documentée.
