# ============================================
# MEDIA SERVER HOME - Makefile
# ============================================
# Quick commands for common operations
#
# Usage:
#   make help       - Show this help message
#   make up         - Start all services
#   make down       - Stop all services
#   make logs       - Show logs (all services)
#   make backup     - Run backup script
#   make test       - Run smoke tests

.PHONY: help up down restart logs status backup restore test clean

# ============================================
# HELP
# ============================================
help:
	@echo "════════════════════════════════════════════════════════════════"
	@echo "  MEDIA SERVER HOME - Makefile Commands"
	@echo "════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "  🚀 DOCKER OPERATIONS:"
	@echo "    make up             - Start all services (EXTRANET + INTRANET)"
	@echo "    make down           - Stop all services"
	@echo "    make restart        - Restart all services"
	@echo "    make logs           - Show logs (all services, follow mode)"
	@echo "    make status         - Show services status"
	@echo ""
	@echo "  📦 VM-EXTRANET (DMZ):"
	@echo "    make up-extranet    - Start EXTRANET services (NPM, OpenVPN)"
	@echo "    make logs-extranet  - Show EXTRANET logs"
	@echo ""
	@echo "  🏠 VM-INTRANET (LAN):"
	@echo "    make up-intranet    - Start INTRANET services (Jellyfin, Immich, etc.)"
	@echo "    make logs-intranet  - Show INTRANET logs"
	@echo ""
	@echo "  💾 BACKUPS & MAINTENANCE:"
	@echo "    make backup         - Run Restic backup (appdata + DB + media)"
	@echo "    make restore        - Restore from latest backup"
	@echo "    make check-backup   - Verify backup integrity"
	@echo "    make test           - Run smoke tests"
	@echo "    make healthcheck    - Check all services health"
	@echo ""
	@echo "  🧹 CLEANUP:"
	@echo "    make clean          - Remove stopped containers + unused volumes"
	@echo "    make prune          - Deep clean (images, volumes, networks)"
	@echo ""
	@echo "  📊 MONITORING:"
	@echo "    make metrics        - Show Prometheus metrics"
	@echo "    make grafana        - Open Grafana dashboard"
	@echo ""
	@echo "════════════════════════════════════════════════════════════════"

# ============================================
# DOCKER OPERATIONS (VM-EXTRANET)
# ============================================
up-extranet:
	@echo "🚀 Starting VM-EXTRANET services (NPM, OpenVPN)..."
	@ssh root@192.168.1.100 "cd /opt/extranet && docker compose up -d"
	@echo "✅ EXTRANET services started"

down-extranet:
	@echo "⏹️  Stopping VM-EXTRANET services..."
	@ssh root@192.168.1.100 "cd /opt/extranet && docker compose down"
	@echo "✅ EXTRANET services stopped"

logs-extranet:
	@echo "📋 Showing VM-EXTRANET logs..."
	@ssh root@192.168.1.100 "cd /opt/extranet && docker compose logs -f"

restart-extranet:
	@echo "🔄 Restarting VM-EXTRANET services..."
	@ssh root@192.168.1.100 "cd /opt/extranet && docker compose restart"
	@echo "✅ EXTRANET services restarted"

# ============================================
# DOCKER OPERATIONS (VM-INTRANET)
# ============================================
up-intranet:
	@echo "🚀 Starting VM-INTRANET services (Jellyfin, Immich, Postgres, etc.)..."
	@ssh root@192.168.1.101 "cd /opt/intranet && docker compose up -d"
	@echo "✅ INTRANET services started"

down-intranet:
	@echo "⏹️  Stopping VM-INTRANET services..."
	@ssh root@192.168.1.101 "cd /opt/intranet && docker compose down"
	@echo "✅ INTRANET services stopped"

logs-intranet:
	@echo "📋 Showing VM-INTRANET logs..."
	@ssh root@192.168.1.101 "cd /opt/intranet && docker compose logs -f"

restart-intranet:
	@echo "🔄 Restarting VM-INTRANET services..."
	@ssh root@192.168.1.101 "cd /opt/intranet && docker compose restart"
	@echo "✅ INTRANET services restarted"

# ============================================
# COMBINED OPERATIONS (BOTH VMS)
# ============================================
up: up-extranet up-intranet
	@echo "✅ All services started on both VMs"

down: down-intranet down-extranet
	@echo "✅ All services stopped on both VMs"

restart: restart-extranet restart-intranet
	@echo "✅ All services restarted"

logs:
	@echo "📋 Choose VM:"
	@echo "  1) VM-EXTRANET logs"
	@echo "  2) VM-INTRANET logs"
	@read -p "Enter choice [1-2]: " choice; \
	case $$choice in \
		1) make logs-extranet ;; \
		2) make logs-intranet ;; \
		*) echo "Invalid choice" ;; \
	esac

status:
	@echo "════════════════════════════════════════════════════════════════"
	@echo "  VM-EXTRANET (192.168.1.100) Status:"
	@echo "════════════════════════════════════════════════════════════════"
	@ssh root@192.168.1.100 "docker compose -f /opt/extranet/docker-compose.yml ps"
	@echo ""
	@echo "════════════════════════════════════════════════════════════════"
	@echo "  VM-INTRANET (192.168.1.101) Status:"
	@echo "════════════════════════════════════════════════════════════════"
	@ssh root@192.168.1.101 "docker compose -f /opt/intranet/docker-compose.yml ps"

# ============================================
# BACKUPS
# ============================================
backup:
	@echo "💾 Starting Restic backup..."
	@ssh root@192.168.1.101 "bash /scripts/backup.sh"
	@echo "✅ Backup completed"

restore:
	@echo "⚠️  WARNING: This will restore from latest backup!"
	@read -p "Are you sure? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ]; then \
		ssh root@192.168.1.101 "bash /scripts/restore.sh"; \
		echo "✅ Restore completed"; \
	else \
		echo "❌ Restore cancelled"; \
	fi

check-backup:
	@echo "🔍 Verifying Restic backup integrity..."
	@ssh root@192.168.1.101 "restic -r /mnt/tank/backups/restic-repo check"
	@echo "✅ Backup integrity verified"

snapshots:
	@echo "📸 Listing Restic snapshots..."
	@ssh root@192.168.1.101 "restic -r /mnt/tank/backups/restic-repo snapshots"

# ============================================
# TESTING & HEALTH
# ============================================
test:
	@echo "🧪 Running smoke tests..."
	@bash tests/smoke-test.sh
	@echo "✅ All tests passed"

healthcheck:
	@echo "🏥 Running healthcheck script..."
	@ssh root@192.168.1.101 "bash /scripts/healthcheck.sh"
	@echo "✅ Healthcheck completed"

# ============================================
# MONITORING
# ============================================
metrics:
	@echo "📊 Opening Prometheus metrics..."
	@xdg-open http://192.168.1.101:9090 2>/dev/null || open http://192.168.1.101:9090 2>/dev/null || echo "Open http://192.168.1.101:9090 in browser"

grafana:
	@echo "📈 Opening Grafana dashboard..."
	@xdg-open https://grafana.elmzn.be 2>/dev/null || open https://grafana.elmzn.be 2>/dev/null || echo "Open https://grafana.elmzn.be in browser"

npm:
	@echo "🌐 Opening Nginx Proxy Manager..."
	@xdg-open http://192.168.1.100:81 2>/dev/null || open http://192.168.1.100:81 2>/dev/null || echo "Open http://192.168.1.100:81 in browser"

# ============================================
# CLEANUP
# ============================================
clean:
	@echo "🧹 Cleaning up stopped containers and unused volumes..."
	@ssh root@192.168.1.100 "docker system prune -f"
	@ssh root@192.168.1.101 "docker system prune -f"
	@echo "✅ Cleanup completed"

prune:
	@echo "⚠️  WARNING: This will remove ALL unused images, volumes, and networks!"
	@read -p "Are you sure? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ]; then \
		ssh root@192.168.1.100 "docker system prune -a --volumes -f"; \
		ssh root@192.168.1.101 "docker system prune -a --volumes -f"; \
		echo "✅ Deep prune completed"; \
	else \
		echo "❌ Prune cancelled"; \
	fi

# ============================================
# UPDATES
# ============================================
update:
	@echo "🔄 Updating Docker images..."
	@ssh root@192.168.1.100 "cd /opt/extranet && docker compose pull && docker compose up -d"
	@ssh root@192.168.1.101 "cd /opt/intranet && docker compose pull && docker compose up -d"
	@echo "✅ All services updated"

# ============================================
# PROXMOX OPERATIONS (requires root on Proxmox host)
# ============================================
vm-start:
	@echo "🚀 Starting VMs on Proxmox..."
	@ssh root@192.168.1.1 "qm start 100 && qm start 101"
	@echo "✅ VMs started (waiting 30s for boot)..."
	@sleep 30

vm-stop:
	@echo "⏹️  Stopping VMs on Proxmox..."
	@ssh root@192.168.1.1 "qm shutdown 100 && qm shutdown 101"
	@echo "✅ VMs stopped"

vm-status:
	@echo "📊 VM Status on Proxmox:"
	@ssh root@192.168.1.1 "qm list"

# ============================================
# DEVELOPMENT
# ============================================
dev:
	@echo "🛠️  Starting development environment..."
	@echo "Not implemented yet"

lint:
	@echo "🔍 Linting configuration files..."
	@yamllint docker-compose*.yml configs/
	@shellcheck scripts/*.sh
	@markdownlint docs/*.md
	@echo "✅ Linting completed"