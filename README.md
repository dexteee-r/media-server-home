# Media Server Home

> Self-hosted media streaming platform with automated backups and monitoring

## Features

- Jellyfin - Media streaming (movies, TV shows, music)
- Immich - Google Photos alternative
- Traefik - Automatic HTTPS
- Prometheus + Grafana - Monitoring
- Automated backups - Restic encrypted backups
- Auto-updates - Watchtower

## Quick Start

```bash
# 1. Clone & configure
git clone <repo-url>
cd media-server-home
cp .env.example .env

# 2. Bootstrap (WSL/Linux)
bash scripts/bootstrap.sh

# 3. Start services
docker compose --profile media --profile photos up -d
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Operations](docs/OPERATIONS.md)
- [Security](docs/SECURITY.md)
- [ADRs](docs/ADR/)

## License

MIT