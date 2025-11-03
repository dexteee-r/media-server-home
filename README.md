# 🏠 Media Server Home

> Self-hosted media streaming platform with **multi-VM security architecture**, automated backups and monitoring

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-8.4-orange)](https://www.proxmox.com/)
[![Docker](https://img.shields.io/badge/Docker-27.x-blue)](https://www.docker.com/)
[![Debian](https://img.shields.io/badge/Debian-13-red)](https://www.debian.org/)

## ✨ Features

### 🎬 Media Streaming
- **Jellyfin** - Movies, TV shows, music streaming with hardware transcoding (Intel QuickSync)
- **Immich** - Self-hosted Google Photos alternative with AI features

### 🔒 Security & Access
- **Nginx Proxy Manager** - Reverse proxy with automatic HTTPS (Let's Encrypt)
- **OpenVPN** - Secure remote access to entire homelab
- **UFW + Fail2ban** - Multi-layer firewall protection
- **Multi-VM isolation** - Separate EXTRANET (DMZ) and INTRANET VMs

### 📊 Monitoring & Backups
- **Prometheus + Grafana** - Real-time metrics and dashboards
- **Restic** - Encrypted automated backups (AES-256)
- **ZFS** - Data integrity with snapshots

### 🌐 Infrastructure
- **Proxmox VE 8.4** - Bare-metal hypervisor with GPU passthrough
- **Debian 13** - Lightweight and stable guest OS
- **Dynamic DNS** - OVH domain (elmzn.be) with ddclient

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│ Proxmox VE 8.4 (Dell OptiPlex 7040)                │
│ i5-6500 | 16GB RAM | 256GB SSD + 500GB HDD         │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────┐   ┌──────────────────┐  │
│  │ VM-EXTRANET (DMZ)    │   │ VM-INTRANET (LAN)│  │
│  │ 192.168.1.100        │   │ 192.168.1.101    │  │
│  │ Debian 13 | 4GB RAM  │   │ Debian 13 | 12GB │  │
│  ├──────────────────────┤   ├──────────────────┤  │
│  │ • NPM (80/443)       │◄──┤ • Jellyfin :8096 │  │
│  │ • OpenVPN (1194)     │   │ • Immich :2283   │  │
│  │ • ddclient (DDNS)    │   │ • Postgres :5432 │  │
│  │ • Fail2ban           │   │ • Prometheus     │  │
│  │ • UFW firewall       │   │ • Grafana :3000  │  │
│  └──────────────────────┘   │ • Restic backups │  │
│         ▲                    └──────────────────┘  │
│         │                           ▲              │
│    Port forward              GPU passthrough       │
│    80/443/1194               Intel HD 530          │
└─────────────────────────────────────────────────────┘
         ▲
         │
   Internet (elmzn.be)
```

**Security model:**
- ✅ INTRANET **NEVER** exposed to Internet
- ✅ All public traffic → EXTRANET (NPM reverse proxy)
- ✅ VPN access for remote management
- ✅ Multi-layer firewall (UFW per VM + Proxmox)

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
cat SETUP.md  # Full installation guide
```

### 3. Deploy VMs
```bash
# Create VM-EXTRANET (Debian 13)
# Create VM-INTRANET (Debian 13)
# See SETUP.md Phase 5-10 for detailed steps
```

### 4. Configure services
```bash
# VM-EXTRANET
docker compose -f docker-compose.extranet.yml up -d

# VM-INTRANET
docker compose -f docker-compose.intranet.yml up -d
```

### 5. Access services
- **Jellyfin:** https://jellyfin.elmzn.be
- **Immich:** https://photos.elmzn.be
- **Grafana:** https://intranet.elmzn.be/grafana

---

## 📚 Documentation

### Essential docs (read first)
- [**SETUP.md**](SETUP.md) - Complete installation guide (10 phases)
- [**CHEATSHEET.md**](CHEATSHEET.md) - Common commands reference
- [**Architecture Diagram**](assets/architecture-proxmox.png) - Visual overview

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
| [009](docs/ADR/009-placement-services.md) | Debian 13 choice | ✅ Adopted |
| [010](docs/ADR/010-DNS_public.md) | Dynamic DNS (OVH) | ✅ Adopted |

[📂 See all ADRs →](docs/ADR/)

---

## 🔧 Tech Stack

### Infrastructure
- **Hypervisor:** Proxmox VE 8.4
- **Guest OS:** Debian 13 (Trixie)
- **Orchestration:** Docker Compose
- **Storage:** ZFS (tank-ssd + tank-hdd)

### Services
- **Reverse Proxy:** Nginx Proxy Manager
- **VPN:** OpenVPN
- **Media:** Jellyfin (with Intel QuickSync)
- **Photos:** Immich + PostgreSQL 16
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
- **RAM:** 16 GB DDR4-2133
- **Storage:** 
  - 256 GB NVMe SSD (Proxmox + VMs + appdata + DB)
  - 500 GB HDD (media + photos + backups)
- **GPU:** Intel HD 530 (QuickSync hardware transcoding)
- **Network:** Intel I219-LM Gigabit Ethernet

---

## 📊 Project Status

### ✅ Completed
- [x] Proxmox VE installed and configured
- [x] Multi-VM architecture deployed (EXTRANET + INTRANET)
- [x] ZFS pools configured (tank-ssd + tank-hdd)
- [x] GPU passthrough working (Intel QuickSync)
- [x] Jellyfin streaming operational
- [x] Immich deployed + mobile app connected
- [x] NPM reverse proxy configured
- [x] OpenVPN access functional
- [x] Prometheus + Grafana monitoring
- [x] Restic automated backups

### 🚧 In Progress
- [ ] Split DNS (Pi-hole LXC)
- [ ] WAF in front of NPM
- [ ] Cloudflare Tunnel alternative

### 📅 Roadmap (6-12 months)
- [ ] HDD upgrade (500GB → 2TB)
- [ ] Additional RAM (16GB → 24GB)
- [ ] Dedicated backup VM (Proxmox Backup Server)

---

## 🔐 Security

### Defense in depth (6 layers)
1. **Box firewall** - Only ports 80/443/1194 forwarded
2. **Proxmox firewall** - Datacenter + VM + Node rules
3. **VM-EXTRANET UFW** - Allow public ports only
4. **VM-INTRANET UFW** - Deny all incoming (except from EXTRANET)
5. **Fail2ban** - Auto-ban brute force attempts
6. **Application auth** - User accounts + strong passwords

### Backup strategy
- **Frequency:** Daily (DB/appdata), Weekly (photos), Monthly (media)
- **Encryption:** AES-256 (Restic)
- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Storage:** Local ZFS + offsite SFTP

---

## 🤝 Contributing

This is a personal homelab project, but feel free to:
- 🐛 Report issues
- 💡 Suggest improvements
- 📖 Use as inspiration for your own homelab

---

## 📝 License

MIT License - see [LICENSE](LICENSE)

---

## 🙏 Acknowledgments

- [Proxmox VE](https://www.proxmox.com/) - Amazing open-source hypervisor
- [Jellyfin](https://jellyfin.org/) - Free media streaming
- [Immich](https://immich.app/) - Best self-hosted photo solution
- [r/selfhosted](https://reddit.com/r/selfhosted) - Awesome community

---

## 📞 Contact

**Portfolio:** [Take a look !](https://mm-elmazani.github.io/mm-elmazani-portfolio/index.html) 
**GitHub:** [@dexteee-r](https://github.com/dexteee-r)  
**Project:** [media-server-home](https://github.com/dexteee-r/media-server-home)

---

*Last updated: November 2025*