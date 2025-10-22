# ADR-006 — Choix de la stack de monitoring : **Prometheus + Grafana**

## 📘 Contexte

Le projet **media-server-home** fonctionne sur un hôte **Proxmox VE** avec une **VM “Services” (Ubuntu Server 24.04)** exécutant l’ensemble des conteneurs Docker :  
- Jellyfin  
- Immich (+ Postgres)  
- Traefik  
- Restic  
- Prometheus / Grafana (monitoring)

L’objectif est de mettre en place une **supervision complète** du système et des services, permettant de :
- surveiller la charge CPU, la RAM, le stockage et la température,  
- détecter les pannes ou comportements anormaux (Docker, réseau, backup),  
- visualiser les métriques en temps réel via un tableau de bord web,  
- centraliser les alertes et logs.

---

## ⚙️ Problème à résoudre

Choisir une **stack de monitoring fiable, légère et intégrée** à l’écosystème Docker / Linux, capable de :
1. S’exécuter dans la VM sans impact notable sur les performances.  
2. Être compatible avec **ZFS**, **Docker**, et **Traefik**.  
3. Exporter des métriques système, conteneurs et disques.  
4. Permettre une visualisation claire et personnalisable.  
5. Pouvoir évoluer vers l’envoi d’alertes (mail, Discord, etc.).

---

## 🧩 Options étudiées

| Option | Description | Avantages | Inconvénients |
|--------|--------------|------------|----------------|
| **Prometheus + Grafana** | Stack standard open-source pour la collecte et la visualisation des métriques. | - Très mature et documentée<br>- Nombreux exporters disponibles<br>- Intégration Docker / Traefik native<br>- Dashboards Grafana réutilisables<br>- Faible empreinte mémoire (~300–400 Mo)<br>- Compatible avec alerting et Promtail | - Configuration initiale manuelle (targets, dashboards)<br>- Nécessite plusieurs conteneurs |
| **Netdata** | Monitoring en temps réel tout-en-un. | - Installation simple, UI immédiate<br>- Découverte automatique des métriques | - Consomme plus de RAM (~1 Go)<br>- Moins modulaire, dépendance agent local |
| **Zabbix** | Solution complète entreprise. | - Interface complète, agents multiples | - Surcharge importante, trop complexe pour un usage domestique |
| **Glances + InfluxDB** | Outil Python + base time-series. | - Léger et minimaliste | - Moins complet (pas de dashboards, alerting limité) |

---

## 🧮 Critères de décision

| Critère | Pondération | Prometheus + Grafana | Netdata | Zabbix | Glances |
|----------|--------------|----------------------|----------|---------|----------|
| **Compatibilité Docker / Linux** | 5 | ✅ Native | ✅ | ⚠️ | ✅ |
| **Exporters disponibles (ZFS, Docker, CPU)** | 5 | ✅ Très nombreux | ⚠️ | ✅ | ⚠️ |
| **Personnalisation des dashboards** | 4 | ✅ Totale | ⚠️ Limitée | ✅ | ⚠️ |
| **Alertes & notifications** | 4 | ✅ Alertmanager intégré | ⚠️ Basique | ✅ | ❌ |
| **Performance / empreinte mémoire** | 4 | ✅ Modérée (~400 Mo) | ⚠️ 1 Go | ⚠️ Lourde | ✅ Légère |
| **Documentation / communauté** | 3 | ✅ Très vaste | ✅ | ✅ | ⚠️ |
| **Intégration avec Traefik / Restic / Docker** | 3 | ✅ Native (exporters & labels) | ⚠️ Partielle | ⚠️ | ❌ |
| **Évolutivité / longévité** | 3 | ✅ Standard DevOps | ⚠️ | ✅ | ⚠️ |
| **Score total (/31)** | — | **29 / 31** | 24 / 31 | 22 / 31 | 19 / 31 |

---

## ✅ Décision finale

> **Adopté : Prometheus + Grafana** comme stack de monitoring principale.

### Justification

- Stack **standard du monde DevOps**, stable et extensible.  
- **Intégration native avec Docker et Traefik** (metrics endpoint).  
- Permet la supervision des conteneurs, du CPU, de la RAM, du stockage ZFS, et du réseau.  
- Dashboards Grafana importables / versionnables dans `/configs/grafana/dashboards/`.  
- Support de l’**alerting** et des **exports vers Grafana Cloud / Discord / email**.  
- Compatible avec les exporters suivants :  
  - `node_exporter` → VM (CPU, RAM, disques)  
  - `cadvisor` → conteneurs Docker  
  - `smartctl_exporter` → disques physiques  
  - `traefik` → reverse proxy metrics  
  - `restic_exporter` (facultatif) → état des sauvegardes  

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Fichiers à créer** | `/configs/prometheus/prometheus.yml` (targets + scrape intervals)<br>`/configs/grafana/datasources.yml` (Prometheus)<br>`/configs/grafana/dashboards/media-server.json` |
| **Réseau Docker** | Ajouter le service `prometheus` et `grafana` au réseau `traefik-net`. |
| **Monitoring hardware (ZFS)** | Activer `smartctl_exporter` dans la VM. |
| **Sauvegardes** | Export des dashboards Grafana dans `/configs/grafana/dashboards/` pour versioning. |
| **Logs / observabilité** | Ajout possible de `Promtail` + `Loki` (future extension). |
| **Performances** | Faible impact sur un i5-6500 (consommation CPU <5 %, RAM <400 Mo). |

---

## 🧩 Exemple d’organisation des fichiers

```
configs/
├─ prometheus/
│ ├─ prometheus.yml
│ └─ alerts/
│ ├─ restic-status.yml
│ └─ disk-space.yml
└─ grafana/
├─ datasources.yml
└─ dashboards/
└─ media-server.json

```

---

## 🔒 Sécurité

- Grafana exposé uniquement sur le réseau `traefik-net` (accès via Traefik).  
- Authentification Grafana activée (admin/password via `.env`).  
- Prometheus en lecture seule (aucune modification externe).  
- Dashboard “public” en lecture seule possible sur le réseau local.

---

## 🔮 Actions suivantes

- [ ] Créer les fichiers `prometheus.yml` et `datasources.yml`.  
- [ ] Définir les dashboards principaux : système, Docker, sauvegardes.  
- [ ] Ajouter un **exporter Restic** ou script custom (état des backups).  
- [ ] Documenter la supervision dans `/docs/OPERATIONS.md` (procédure de vérification).  
- [ ] Évaluer extension **Loki / Promtail** pour la centralisation des logs.

---

🗓️ **Journal de bord Future desicion** 
- Décision : adoption de **Prometheus + Grafana** comme stack de monitoring.  
- Raisons : standard DevOps, modularité, faible empreinte, intégration Docker/Traefik.  
- Étape suivante : compléter **ARCHITECTURE.md** et **SECURITY.md**.

### 💡 Résumé pour ton Wiki

ADR-006 — Stack de monitoring : Prometheus + Grafana adoptée.
Motifs : intégration Docker/Traefik native, dashboards personnalisables, faible empreinte.
Impact : ajout des fichiers de configuration sous /configs/prometheus/ et /configs/grafana/.