# 🏠 Media Server Home

> Complete homelab with media services, web hosting, VPN, and password manager. Proxmox + ZFS + Docker infrastructure.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-8.4-orange)](https://www.proxmox.com/)
[![Docker](https://img.shields.io/badge/Docker-27.x-blue)](https://www.docker.com/)
[![Debian](https://img.shields.io/badge/Debian-13-red)](https://www.debian.org/)
[![Made with Love](https://img.shields.io/badge/Made%20with-❤️-red)]()

## ✨ Features

### 🎬 Media Streaming
- **Jellyfin** - Movies, TV shows, music streaming with hardware transcoding (Intel QuickSync)
- **Immich** - Self-hosted Google Photos alternative with AI features

### 🔐 Security & Access
- **Nginx Proxy Manager** - Reverse proxy with automatic HTTPS (Let's Encrypt)
- **OpenVPN/WireGuard** - Secure remote access to entire homelab
- **Vaultwarden** - Self-hosted password manager (Bitwarden compatible)
- **TinyAuth** - Lightweight authentication for NPM
- **UFW + Fail2ban** - Multi-layer firewall protection
- **Multi-VM isolation** - Separate EXTRANET (DMZ) and INTRANET VMs

### 🌐 Web Hosting
- **Nginx Web Server** - Host personal websites and projects
- **MariaDB** - Database backend for web applications
- **PHPMyAdmin** - Web-based database management

### 📊 Monitoring & Backups
- **Prometheus + Grafana** - Real-time metrics and dashboards
- **Restic** - Encrypted automated backups (AES-256)
- **ZFS + NFS** - Data integrity with snapshots, centralized storage

### 🌐 Infrastructure
- **Proxmox VE 8.4** - Bare-metal hypervisor with GPU passthrough
- **Debian 13** - Lightweight and stable guest OS
- **ZFS + NFS** - Shared storage across VMs
- **Dynamic DNS** - OVH domain (elmzn.be) with ddclient

---

## 🗺️ Architecture
```
┌───────────────────────────────────────────────────┐
│ Proxmox VE 8.4 (Dell OptiPlex 7040)                │
│ i5-6500 | 16GB RAM | 256GB SSD + 500GB HDD         │
│                                                     │
│ Storage (ZFS + NFS)                                 │
│ ├─ tank-ssd (15 GB)  → appdata, postgres          │
│ └─ tank-hdd (450 GB) → media, photos, backups     │
├───────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────┐   ┌──────────────────┐  │
│  │ VM-EXTRANET (DMZ)    │   │ VM-INTRANET (LAN)│  │
│  │ 192.168.1.111        │   │ 192.168.1.101    │  │
│  │ Debian 13 | 4GB RAM  │   │ Debian 13 | 12GB │  │
│  ├──────────────────────┤   ├──────────────────┤  │
│  │ • NPM (80/443)       │◄──┤ • Jellyfin :8096 │  │
│  │ • OpenVPN (1194)     │   │ • Immich :2283   │  │
│  │ • Vaultwarden :8080  │   │ • Postgres :5432 │  │
│  │ • TinyAuth           │   │ • Prometheus     │  │
│  │ • ddclient (DDNS)    │   │ • Grafana :3000  │  │
│  │ • Fail2ban           │   │ • Nginx Web :8081│  │
│  │ • UFW firewall       │   │ • MariaDB :3306  │  │
│  │ • NFS: /mnt/logs     │   │ • Restic backups │  │
│  └──────────────────────┘   │ • NFS: 5 mounts  │  │
│         ▲                    └──────────────────┘  │
│         │                           ▲              │
│    Port forward              GPU passthrough       │
│    80/443/1194               Intel HD 530          │
└───────────────────────────────────────────────────┘
         ▲
         │
   Internet (elmzn.be)
```

**Security model:**
- ✅ INTRANET **NEVER** exposed to Internet
- ✅ All public traffic → EXTRANET (NPM reverse proxy)
- ✅ VPN access for remote management
- ✅ Multi-layer firewall (UFW per VM + Proxmox)
- ✅ Vaultwarden accessible only via VPN

---

## 📊 Project Status - Updated November 11, 2025

### ✅ Deployed and Operational
- [x] **Infrastructure**
  - Proxmox VE 8.4 configured (bare-metal)
  - ZFS pools: tank-ssd (15 GB), tank-hdd (450 GB)
  - NFS server: 6 exports active
  - GPU passthrough: Intel HD 530 working
  
- [x] **VM-INTRANET** (192.168.1.101) - 10 Docker containers
  - Jellyfin (streaming + hardware transcoding)
  - Immich (photo management + mobile app)
  - PostgreSQL 16 (Immich database)
  - Redis (Immich cache)
  - Prometheus (metrics collection)
  - Grafana (monitoring dashboards)
  - Node Exporter (system metrics)
  - Nginx Proxy Manager (existing, internal use)
  
- [x] **VM-EXTRANET** (192.168.1.111) - Created, ready for deployment

### 🔧 In Progress (Next Session)
- [ ] **VM-EXTRANET Services**
  - Docker installation
  - Nginx Proxy Manager (public-facing)
  - OpenVPN or WireGuard (VPN access)
  - Vaultwarden (password manager)
  - TinyAuth (authentication layer)
  - Fail2ban + UFW (security hardening)
  
- [ ] **Web Hosting (VM-INTRANET)**
  - Nginx web server deployment
  - MariaDB for web applications
  - Reverse proxy configuration (EXTRANET → INTRANET)
  - Personal websites deployment

### 📅 Planned Improvements (3-6 months)
- [ ] **Storage Upgrade**
  - Replace 500GB HDD with 2x HDD (mirror) + backup disk
  - ZFS quotas implementation (after hardware upgrade)
  - Expand to 2-4 TB total capacity
  
- [ ] **Infrastructure**
  - RAM upgrade (16GB → 24-32GB) for dual channel + Immich ML
  - Split DNS (Pi-hole LXC)
  - Advanced monitoring (alerting rules)
  - Automated testing suite

### 🎯 Services Access (Current)

**LAN Access (192.168.1.0/24):**
| Service | URL | Status |
|---------|-----|--------|
| Jellyfin | http://192.168.1.101:8096 | ✅ Operational |
| Immich | http://192.168.1.101:2283 | ✅ Operational |
| Grafana | http://192.168.1.101:3000 | ✅ Operational |
| Prometheus | http://192.168.1.101:9090 | ✅ Operational |
| Proxmox | https://192.168.1.100:8006 | ✅ Operational |

**Internet Access (Coming Soon):**
| Service | URL | Status |
|---------|-----|--------|
| Jellyfin | https://media.elmzn.be | 📋 Planned |
| Immich | https://photos.elmzn.be | 📋 Planned |
| Vaultwarden | https://vault.elmzn.be | 📋 Planned (VPN only) |
| Web Sites | https://site1.elmzn.be | 📋 Planned |

---

## 🚀 Quick Start

### Prerequisites
- Proxmox VE 8.x installed
- 16GB+ RAM recommended
- Domain name (optional, for HTTPS)

### 1. Clone repository
```bash
git clone https://github.com/dexteee-r/media-server-home.git
cd media-server-home
```

### 2. Review architecture
```bash
# Read documentation
cat docs/ADR/008-architecture-multi-vm.md
cat docs/ADR/011-zfs-nfs-partage-stockage.md
cat SETUP.md  # Full installation guide
```

### 3. Deploy infrastructure
```bash
# Create ZFS pools on Proxmox
# Configure NFS server
# Create VMs (EXTRANET + INTRANET)
# See SETUP.md Phase 1-10 for detailed steps
```

### 4. Deploy services
```bash
# VM-EXTRANET
cd /opt/extranet
docker compose up -d

# VM-INTRANET
cd /opt/intranet
docker compose up -d
```

### 5. Access services
- **Jellyfin:** http://192.168.1.101:8096 (LAN) or https://media.elmzn.be (Internet)
- **Immich:** http://192.168.1.101:2283 (LAN) or https://photos.elmzn.be (Internet)
- **Grafana:** http://192.168.1.101:3000 (LAN)
- **Vaultwarden:** https://vault.elmzn.be (VPN only)

---

## 📚 Documentation

### Essential docs (read first)
- [**SETUP.md**](SETUP.md) - Complete installation guide (10 phases)
- [**CHEATSHEET.md**](CHEATSHEET.md) - Common commands reference (ZFS, NFS, Docker)
- [**Architecture Diagram**](assets/architecture-proxmox.png) - Visual overview
- [**Journal de Bord**](docs/journal/journal_de_bord.md) - Development log

### Architecture Decision Records (ADR)
All technical decisions are documented:

| ADR | Topic | Status |
|-----|-------|--------|
| [001](docs/ADR/001-hyperviseur-proxmox.md) | Hypervisor choice (Proxmox VE) | ✅ Adopted |
| [002](docs/ADR/002-docker-vs-lxc.md) | Docker Compose vs LXC | ✅ Adopted |
| [003](docs/ADR/003-traefik-vs-nginx.md) | NPM vs Traefik | ✅ Adopted |
| [004](docs/ADR/004-zfs-vs-btrfs.md) | ZFS vs Btrfs | ✅ Adopted |
| [005](docs/ADR/005-backup-strategy.md) | Restic backup strategy | ✅ Adopted |
| [006](docs/ADR/006-monitoring-stack.md) | Prometheus + Grafana | ✅ Adopted |
| [007](docs/ADR/007-strategie-stockage.md) | SSD/HDD storage split | ✅ Adopted |
| [008](docs/ADR/008-architecture-multi-vm.md) | Multi-VM security architecture | ✅ Adopted |
| [009](docs/ADR/009-placement-services.md) | Service placement strategy | ✅ Adopted |
| [010](docs/ADR/010-DNS_public.md) | Dynamic DNS (OVH) | ✅ Adopted |
| [011](docs/ADR/011-zfs-nfs-partage-stockage.md) | ZFS + NFS storage sharing | ✅ Adopted |
| [012](docs/ADR/012-pas-de-quotas-zfs-temporaire.md) | No ZFS quotas (temporary) | ⏳ Temporary |
| [013](docs/ADR/013-tinyauth-authentification.md) | TinyAuth for NPM auth | 📋 Planned |

[📂 See all ADRs →](docs/ADR/)

---

## 🔧 Tech Stack

### Infrastructure
- **Hypervisor:** Proxmox VE 8.4
- **Guest OS:** Debian 13 (Trixie)
- **Orchestration:** Docker Compose
- **Storage:** ZFS (tank-ssd + tank-hdd) + NFS
- **Users:** intraadmin (INTRANET), extraadmin (EXTRANET)

### Services
- **Reverse Proxy:** Nginx Proxy Manager
- **Authentication:** TinyAuth (planned)
- **VPN:** OpenVPN or WireGuard (planned)
- **Password Manager:** Vaultwarden (planned)
- **Media:** Jellyfin (with Intel QuickSync)
- **Photos:** Immich + PostgreSQL 16
- **Web Server:** Nginx (planned)
- **Database:** MariaDB (planned)
- **Monitoring:** Prometheus + Grafana
- **Backups:** Restic (encrypted AES-256)

### Network
- **DNS:** OVH (elmzn.be) + ddclient (DDNS)
- **Firewall:** UFW (per VM) + Fail2ban
- **SSL:** Let's Encrypt (via NPM)

---

## 🛠️ Hardware

**Dell OptiPlex 7040**
- **CPU:** Intel Core i5-6500 (4C/4T @ 3.2-3.6 GHz)
- **RAM:** 16 GB DDR4-2133 (single channel)
- **Storage:** 
  - 256 GB NVMe SSD (Proxmox + VMs)
    - 15 GB ZFS (tank-ssd): appdata + postgres
  - 500 GB HDD (data)
    - 450 GB ZFS (tank-hdd): media + photos + backups + logs
- **GPU:** Intel HD 530 (QuickSync hardware transcoding)
- **Network:** Intel I219-LM Gigabit Ethernet

**Storage Usage (as of Nov 11, 2025):**
- tank-ssd: 977M / 15 GB (6.5%)
- tank-hdd: 505M / 450 GB (0.1%)
- **Total used:** ~1.5 GB / 465 GB

---

## 🔐 Security

### Defense in depth (6 layers)
1. **Box firewall** - Only ports 80/443/1194 forwarded to EXTRANET
2. **Proxmox firewall** - Datacenter + VM + Node rules
3. **VM-EXTRANET UFW** - Allow public ports only (80/443/1194)
4. **VM-INTRANET UFW** - Deny all incoming (except from EXTRANET + LAN)
5. **Fail2ban** - Auto-ban brute force attempts (planned)
6. **Application auth** - TinyAuth + user accounts + strong passwords

### Network Isolation
- **INTRANET:** NEVER exposed to Internet, accessible only from LAN or via VPN
- **EXTRANET:** DMZ zone, only reverse proxy exposed
- **Vaultwarden:** Accessible ONLY via VPN (extra security layer)

### Backup Strategy
- **Frequency:** Daily (DB/appdata), Weekly (photos), Monthly (media)
- **Encryption:** AES-256 (Restic)
- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Storage:** Local ZFS snapshots + Restic encrypted backups

---

## 💡 Key Technical Decisions

### Why ZFS on Proxmox + NFS?
Instead of creating ZFS pools inside VMs, we centralize storage on the Proxmox host:
- ✅ **Centralized snapshots:** `zfs snapshot` from Proxmox for all VMs
- ✅ **SMART monitoring:** Proxmox monitors disk health
- ✅ **Flexible sharing:** Easy to add new VMs via NFS
- ✅ **Performance:** Native ZFS + minimal NFS overhead (~5%)

See [ADR 011](docs/ADR/011-zfs-nfs-partage-stockage.md) for full rationale.

### Why no ZFS quotas (for now)?
Current storage is limited (500 GB) and a hardware upgrade is planned within 3-6 months:
- 📅 **Upgrade plan:** 2x HDD in mirror + backup disk (2-4 TB total)
- ⏳ **Temporary:** No quotas until upgrade (flexibility for testing)
- ✅ **Future:** Quotas will be applied after hardware upgrade

See [ADR 012](docs/ADR/012-pas-de-quotas-zfs-temporaire.md) for details.

### Why TinyAuth instead of Authelia?
For a personal homelab, TinyAuth provides sufficient security with minimal complexity:
- ✅ **Lightweight:** Low resource usage (important for 4 GB EXTRANET VM)
- ✅ **Simple:** Easy to configure and maintain
- ✅ **Sufficient:** Meets all authentication needs for personal use
- ❌ **Authelia:** Overkill for homelab (more features than needed)

See [ADR 013](docs/ADR/013-tinyauth-authentification.md) for rationale.

---

## 🤝 Contributing

This is a personal homelab project, but feel free to:
- 🐛 Report issues
- 💡 Suggest improvements
- 📖 Use as inspiration for your own homelab

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 🙏 Acknowledgments

- [Proxmox VE](https://www.proxmox.com/) - Amazing open-source hypervisor
- [Jellyfin](https://jellyfin.org/) - Free media streaming
- [Immich](https://immich.app/) - Best self-hosted photo solution
- [Vaultwarden](https://github.com/dials/vaultwarden) - Lightweight Bitwarden server
- [r/selfhosted](https://reddit.com/r/selfhosted) - Awesome community
- **Claude (Anthropic)** - AI assistant for technical architecture and documentation

---

## 📞 Contact

**Portfolio:** [Take a look !](https://mm-elmazani.github.io/mm-elmazani-portfolio/index.html)  
**GitHub:** [@dexteee-r](https://github.com/dexteee-r)  
**Project:** [media-server-home](https://github.com/dexteee-r/media-server-home)

---

*Last updated: November 11, 2025*
