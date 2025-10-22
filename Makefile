.PHONY: help up down logs

help:
	@echo "Commandes disponibles:"
	@echo "  make up       - Demarre les services"
	@echo "  make down     - Arrete les services"
	@echo "  make logs     - Affiche les logs"

up:
	docker compose --profile media --profile photos up -d

down:
	docker compose down

logs:
	docker compose logs -f