# ADR-006 — Choix de la stack de monitoring : **Prometheus + Grafana**

## 📘 Contexte

Le projet **media-server-home** fonctionne sur un hôte **Proxmox VE** avec deux VMs Debian 12 :

- **VM-EXTRANET (DMZ)** : héberge les services exposés (Nginx Proxy Manager, OpenVPN, node_exporter).  
- **VM-INTRANET (LAN)** : héberge les services internes (Jellyfin, Immich, Postgres, Prometheus, Grafana, Restic).

L’objectif du monitoring est de disposer d’une **vision centralisée** de l’état du système, des conteneurs, du stockage et des sauvegardes.

---

## ⚙️ Problème à résoudre

Choisir une stack de monitoring **légère, standard et extensible**, capable de :
- collecter les métriques des deux VMs (EXTRANET et INTRANET) ;
- suivre l’état du pool ZFS, des conteneurs Docker et des sauvegardes Restic ;
- fournir des alertes et tableaux de bord personnalisés ;
- s’intégrer sans surcharge à la stack Docker existante.

---

## 🧩 Options étudiées

| Stack | Avantages | Inconvénients |
|--------|------------|----------------|
| **Prometheus + Grafana** | - Stack standard DevOps<br>- Exporters nombreux (ZFS, Docker, OpenVPN, etc.)<br>- Intégration Docker native<br>- Faible empreinte mémoire | - Configuration manuelle initiale |
| **Netdata** | Installation simple, UI instantanée | Consomme davantage (~1 Go RAM) |
| **Zabbix** | Interface complète entreprise | Trop lourd pour une infra domestique |
| **Glances + InfluxDB** | Léger, minimaliste | Peu de personnalisation, pas d’alerting |

---

## 🧮 Critères de décision

| Critère | Pondération | Prometheus + Grafana | Netdata | Zabbix | Glances |
|----------|--------------|----------------------|----------|---------|----------|
| **Compatibilité Docker / Linux** | 5 | ✅ | ✅ | ⚠️ | ✅ |
| **Exporters disponibles** | 5 | ✅ Très nombreux | ⚠️ Limités | ✅ | ⚠️ |
| **Personnalisation dashboards** | 4 | ✅ | ⚠️ | ✅ | ⚠️ |
| **Alerting & notifications** | 4 | ✅ | ⚠️ | ✅ | ❌ |
| **Performance / empreinte mémoire** | 4 | ✅ ~400 Mo | ⚠️ ~1 Go | ⚠️ | ✅ |
| **Documentation / communauté** | 3 | ✅ Large | ✅ | ✅ | ⚠️ |
| **Évolutivité / longévité** | 3 | ✅ | ⚠️ | ✅ | ⚠️ |
| **Score total (/28)** | — | **27 / 28** | 22 | 23 | 19 |

---

## ✅ Décision finale

> **Adopté : Prometheus + Grafana** comme stack de monitoring principale.

### Justification
- Stack DevOps standard, compatible Docker & multi-VM.  
- Exporters variés : ZFS, Docker, OpenVPN, NPM, Restic.  
- Visualisation centralisée (Grafana) + alerting intégré.  
- Intégration simple dans la VM-INTRANET, avec cibles (targets) EXTRANET.

---

## 🔁 Conséquences & impacts

| Aspect | Impact |
|---------|--------|
| **Déploiement** | Prometheus et Grafana tournent sur la VM-INTRANET. |
| **Collecte multi-VM** | Scrape des exporters installés sur EXTRANET et INTRANET. |
| **Sécurité** | Ports metrics ouverts uniquement à `192.168.x.x` et `10.10.x.x`. |
| **Dashboards** | Stockés et versionnés dans `/configs/grafana/dashboards/`. |
| **Alertes** | Option : Alertmanager (mail/Discord) connecté à Prometheus. |

---

## 🧩 Multi-VM monitoring

### 🧱 Architecture du monitoring

```

+----------------------------------------------------------+

| VM-INTRANET (LAN)                                            |
| ------------------------------------------------------------ |
| Prometheus (9090) ← Scrape exporters EXTRANET + INTRANET     |
| Grafana (3000)  ← Dashboards, alerting, backup Restic        |
| node_exporter, cadvisor, smartctl_exporter, restic_exporter  |
| +----------------------------------------------------------+ |

```
            ↑                        ↑
            |                        |
            |                        |
```

+----------------------+     +----------------------+
| VM-EXTRANET (DMZ)    |     | VM-INTRANET (local)  |
|----------------------|     |----------------------|
| node_exporter (9100) |     | node_exporter (9100) |
| openvpn_exporter     |     | smartctl_exporter    |
| npm-exporter (option)|     | cadvisor             |
+----------------------+     +----------------------+

````

---

### 🔗 Cibles Prometheus (`prometheus.yml`)

```yaml
scrape_configs:
  - job_name: 'node_intranet'
    static_configs:
      - targets: ['192.168.1.10:9100']

  - job_name: 'node_extranet'
    static_configs:
      - targets: ['10.10.0.10:9100']

  - job_name: 'docker'
    static_configs:
      - targets: ['192.168.1.10:8080']

  - job_name: 'restic'
    static_configs:
      - targets: ['192.168.1.10:9888']

  - job_name: 'openvpn'
    static_configs:
      - targets: ['10.10.0.10:9176']

  - job_name: 'npm'
    static_configs:
      - targets: ['10.10.0.10:9278'] # Si npm-exporter est activé
````

> 💡 Les exporters sensibles (OpenVPN, NPM) sont restreints via pare-feu à `192.168.1.10` (Prometheus).

---

### 🔐 Sécurité

| Élément                 | Protection                                                     |
| ----------------------- | -------------------------------------------------------------- |
| **Accès Prometheus**    | Limité au LAN (192.168.x.x)                                    |
| **Accès Grafana**       | HTTPS via NPM                                                  |
| **Exporters EXTRANET**  | Restreints à IP Prometheus                                     |
| **Sauvegardes Grafana** | Export JSON des dashboards dans `/configs/grafana/dashboards/` |
| **Logs / alertes**      | Conservés dans `/mnt/tank/appdata/logs/monitoring`             |

---

### 📊 Dashboards recommandés

| Dashboard            | Source                   | VM concernée |
| -------------------- | ------------------------ | ------------ |
| System Overview      | GrafanaLabs ID 1860      | Les deux     |
| Docker Containers    | GrafanaLabs ID 179       | INTRANET     |
| ZFS / Disks          | Custom (local)           | INTRANET     |
| Restic Backup Status | Custom exporter          | INTRANET     |
| NPM Metrics          | npm-exporter (optionnel) | EXTRANET     |
| OpenVPN Sessions     | openvpn-exporter         | EXTRANET     |

---

### 🧠 Alerting (optionnel)

* **Alertmanager** déployé sur INTRANET.
* Alerte si :

  * backup Restic échoue plus de 48h ;
  * pool ZFS dégradé ;
  * service Docker down ;
  * exporter EXTRANET injoignable.
* Notifications : Discord, email ou Telegram.

---

## 🔮 Actions suivantes

* [ ] Ajouter `openvpn-exporter` et `npm-exporter` sur EXTRANET.
* [ ] Créer un dashboard "Infrastructure Overview" multi-VM.
* [ ] Sauvegarder régulièrement la config Grafana (`datasources.yml`, `dashboards/`).
* [ ] Intégrer alertes Restic et ZFS dans Grafana.
* [ ] Évaluer extension future vers Grafana Loki (logs centralisés).

---

🗓️ **Journal de bord – 05/11/2025**

* Ajout de la section *Multi-VM monitoring*.
* Prometheus centralisé sur INTRANET.
* Exporters installés sur les deux VMs.
* Sécurité des cibles et supervision complète de la stack.
