# ADR-003 — Choix du reverse proxy : **Traefik vs Nginx Proxy Manager**

## 📘 Contexte

Le projet **media-server-home** doit exposer plusieurs services web internes accessibles depuis le réseau local et, à terme, éventuellement à distance via VPN (Tailscale/WireGuard).

Services concernés :
- **Jellyfin** — streaming multimédia (port 8096)
- **Immich** — gestion photos et API mobile (ports 2283, 3001)
- **Prometheus** — métriques système (port 9090)
- **Grafana** — visualisation (port 3000)
- **Traefik / Reverse Proxy** — point d’entrée unique (port 80/443)

Le reverse proxy aura pour rôle :
1. Centraliser le trafic entrant (HTTP/HTTPS).  
2. Fournir des certificats SSL (même en LAN via ACME ou self-signed).  
3. Simplifier la gestion des sous-domaines :  
   - `jellyfin.home.arpa`  
   - `photos.home.arpa`  
   - `grafana.home.arpa`  
4. Appliquer les middlewares : authentification, redirections, headers de sécurité.  
5. (Plus tard) Supporter une **exposition sécurisée** via VPN ou DNS dynamique (Tailscale).

---

## ⚙️ Problème à résoudre

Trouver un reverse proxy qui :
- soit compatible avec **Docker Compose** et les labels dynamiques,  
- gère automatiquement le **HTTPS**,  
- permette la **supervision facile** (tableau de bord, logs),  
- reste **léger** et **auto-hébergeable** dans une VM Ubuntu (sans dépendance cloud).

---

## 🧩 Options étudiées

| Option | Description | Avantages | Inconvénients |
|--------|--------------|------------|----------------|
| **Traefik** | Reverse proxy moderne en Go, compatible Docker labels, support ACME (Let’s Encrypt, self-signed, Tailscale). | - Configuration dynamique via labels Docker<br>- Dashboard intégré<br>- Certificats auto-renouvelés<br>- Middlewares (Auth, Rate Limit, Headers, Redirects)<br>- Intégration Prometheus native | - Courbe d’apprentissage un peu plus raide<br>- Configuration plus verbeuse au début |
| **Nginx Proxy Manager (NPM)** | Interface web (GUI) basée sur Nginx et SQLite pour créer facilement des proxies HTTPS. | - Très simple à utiliser via UI<br>- Parfait pour débutants<br>- Interface web claire pour gérer certificats | - Moins automatisable<br>- Pas d’intégration directe Docker labels<br>- Moins flexible pour stack dynamique (Immich, Prometheus)<br>- Dépend d’une base SQLite |
| **Caddy** *(alternative étudiée)* | Serveur HTTP tout-en-un avec HTTPS auto. | - Très simple à configurer<br>- Performance élevée<br>- Certificats automatiques | - Moins d’intégration Docker avancée<br>- Communauté plus restreinte pour stack multimédia |

---

## 🧮 Critères de décision

| Critère | Pondération | Traefik | Nginx PM | Caddy |
|----------|--------------|----------|-----------|--------|
| **Compatibilité Docker / labels automatiques** | 5 | ✅ Native | ❌ | ⚠️ |
| **HTTPS automatique (ACME, self-signed)** | 5 | ✅ | ✅ | ✅ |
| **Dashboard / supervision intégrée** | 4 | ✅ | ✅ (UI simple) | ⚠️ |
| **Automatisation CI/CD / Makefile** | 4 | ✅ | ⚠️ Manuel via UI | ⚠️ |
| **Sécurité (middlewares, rate-limit, HSTS)** | 4 | ✅ Riches | ⚠️ Limité | ⚠️ |
| **Intégration Prometheus / monitoring** | 3 | ✅ Native | ❌ | ⚠️ |
| **Ressources système (RAM/CPU)** | 3 | ✅ Léger | ⚠️ +SQLite overhead | ✅ Léger |
| **Courbe d’apprentissage** | 2 | ⚠️ Moyenne | ✅ Très simple | ✅ |
| **Communauté & maintenance** | 3 | ✅ Très active | ✅ Active | ⚠️ Plus restreinte |
| **Score total (/33)** | – | **31 / 33** | 25 / 33 | 24 / 33 |

---

## ✅ Décision finale

> **Adopté : Traefik** comme reverse proxy principal du projet.

### Justification

- **Intégration native avec Docker Compose** → gestion automatique des routes via labels (`traefik.http.routers.*`).  
- **Configuration déclarative** (YAML + labels) → versionnée dans Git, portable.  
- **Support HTTPS automatique** via ACME, DNS-01, ou certificats internes pour réseau LAN.  
- **Dashboard web sécurisé** (accessible via `/dashboard/`) → supervision centralisée.  
- **Middlewares intégrés** → BasicAuth, RateLimit, Security Headers.  
- **Compatibilité Prometheus / Grafana** → monitoring complet.  
- **Faible empreinte mémoire** (~50–100 Mo RAM).

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Fichier `docker-compose.yml`** | Ajout d’un service `traefik` avec volumes `traefik.yml` + dossier `dynamic/`. |
| **Répertoires créés** | `/configs/traefik/traefik.yml` (statique), `/configs/traefik/dynamic/*.yml` (middlewares/routes). |
| **Réseau Docker** | Création d’un bridge `traefik-net` relié à tous les conteneurs exposés. |
| **Sécurité** | HTTPS interne automatique, BasicAuth sur dashboard, headers CSP et HSTS. |
| **Monitoring** | Intégration directe Prometheus (`:8082/metrics`). |
| **Wiki GitHub** | Section “Architecture réseau & proxy” à documenter avec schéma Mermaid. |

---

## 🔮 Actions suivantes

- [ ] Créer `configs/traefik/traefik.yml` (config statique : entrypoints, providers, API).  
- [ ] Créer `configs/traefik/dynamic/middlewares.yml` (auth, headers, rate-limit).  
- [ ] Créer `configs/traefik/dynamic/routes.yml` (si pas de labels dans Compose).  
- [ ] Définir le réseau Docker `traefik-net` dans `docker-compose.yml`.  
- [ ] Documenter l’architecture réseau dans `/docs/ARCHITECTURE.md`.  
- [ ] Configurer le Makefile (`make up`, `make logs`, `make reload`).

---

🗓️ **Journal de bord – 23/10/2025**  
- Décision : adoption de **Traefik** comme reverse proxy.  
- Raisons : intégration Docker native, HTTPS auto, monitoring Prometheus, config Git-friendly.  
- Étape suivante : rédaction du **docker-compose.yml minimal** et création du dossier `/configs/traefik/`.

