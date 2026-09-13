COMPOSE ?= docker compose
RUN     := $(COMPOSE) run --rm tools
PROD    := $(COMPOSE) --env-file .env.production -f compose.prod.yml
ARGS    ?=

KAMAL_VERSION ?= v2.12.0
KAMAL_TTY     ?= -it
# Sur Linux, installer Kamal (gem install kamal) et lancer : make kamal-deploy KAMAL=kamal
KAMAL ?= docker run $(KAMAL_TTY) --rm --env-file .env.kamal \
	-v "$(CURDIR):/workdir" \
	-v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
	-e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
	-v /var/run/docker.sock:/var/run/docker.sock \
	ghcr.io/basecamp/kamal:$(KAMAL_VERSION)

.DEFAULT_GOAL := help
.PHONY: help setup build up down destroy console shell migrate seed reset test lint security coverage docs docs-lint web-install web-dev web-test web-lint web-build secret prod-build prod-up prod-seed prod-logs prod-down prod-backup kamal-config kamal-setup kamal-deploy kamal-seed kamal-logs kamal-console kamal-rollback

help: ## Liste les commandes disponibles
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Première installation : image, base et 10 013 recettes de démo
	@test -f .env || cp .env.example .env
	$(COMPOSE) build
	$(RUN) bin/rails db:prepare

build: ## Reconstruit l'image de développement (après un changement de Gemfile)
	$(COMPOSE) build

up: ## Démarre l'API sur http://localhost:3000
	$(COMPOSE) up api

down: ## Arrête les conteneurs du projet
	$(COMPOSE) down

destroy: ## Supprime les conteneurs ET le volume Postgres du projet
	$(COMPOSE) down --volumes --remove-orphans

console: ## Console Rails
	$(RUN) bin/rails console

shell: ## Shell dans le conteneur outils
	$(RUN) bash

migrate: ## Applique les migrations
	$(RUN) bin/rails db:migrate

seed: ## Charge les recettes (sans effet si déjà chargées)
	$(RUN) bin/rails db:seed

reset: ## Recrée la base de développement et recharge les recettes
	$(RUN) bin/rails db:reset

test: ## Suite RSpec — ARGS="spec/chemin_spec.rb" pour cibler
	$(COMPOSE) run --rm -e RAILS_ENV=test -e API_KEY= -e CORS_ORIGINS= -e RATE_LIMIT_PER_MINUTE= tools bash -c "bin/rails db:create db:schema:load && bundle exec rspec $(ARGS)"

lint: ## RuboCop (style Rails omakase)
	$(RUN) bin/rubocop

security: ## Brakeman (analyse de sécurité statique)
	$(RUN) bin/brakeman --no-pager

coverage: ## Suite complète avec seuil de couverture, comme en CI
	$(COMPOSE) run --rm -e RAILS_ENV=test -e CI=true -e API_KEY= -e CORS_ORIGINS= -e RATE_LIMIT_PER_MINUTE= tools bash -c "bin/rails db:create db:schema:load && bundle exec rspec"

docs: ## Documentation de l'API sur http://localhost:8080
	$(COMPOSE) --profile docs up docs

docs-lint: ## Valide docs/v1/openapi.yaml
	npx --yes @redocly/cli@1.34.20 lint docs/v1/openapi.yaml

web-install: ## Installe les dépendances du front (Node >= 18.18)
	cd web && npm ci

web-dev: ## Front sur http://localhost:5173 (lancer d'abord make up)
	cd web && npm run dev

web-test: ## Tests du front
	cd web && npm test

web-lint: ## Lint du front
	cd web && npm run lint

web-build: ## Compile le front dans web/dist
	cd web && npm run build

secret: ## Génère une valeur pour SECRET_KEY_BASE
	@openssl rand -hex 64

prod-build: ## Construit l'image de production (API + front)
	$(PROD) build

prod-up: ## Démarre la production : app, Postgres, Caddy (HTTPS)
	$(PROD) up -d

prod-seed: ## Charge les recettes en production (sans effet si déjà chargées)
	$(PROD) exec app ./bin/rails db:seed

prod-logs: ## Journaux de l'application en production
	$(PROD) logs -f app

prod-down: ## Arrête la production (les données sont conservées)
	$(PROD) down

prod-backup: ## Sauvegarde la base dans backups/
	@mkdir -p backups
	$(PROD) exec -T db sh -c 'pg_dump -U "$$POSTGRES_USER" "$$POSTGRES_DB"' | gzip > backups/$$(date +%Y-%m-%d-%H%M).sql.gz
	@ls -lh backups | tail -1

.env.kamal:
	@echo "Fichier .env.kamal manquant : cp .env.kamal.example .env.kamal, puis remplissez-le." && exit 1

kamal-config: .env.kamal ## Kamal : affiche la configuration résolue, sans rien déployer
	$(KAMAL) config

kamal-setup: .env.kamal ## Kamal : premier déploiement (Docker sur le serveur, Postgres, application)
	$(KAMAL) setup

kamal-deploy: .env.kamal ## Kamal : déploie la version courante sans interruption
	$(KAMAL) deploy

kamal-seed: .env.kamal ## Kamal : charge les recettes (sans effet si déjà chargées)
	$(KAMAL) seed

kamal-logs: .env.kamal ## Kamal : journaux de l'application
	$(KAMAL) logs

kamal-console: .env.kamal ## Kamal : console Rails en production
	$(KAMAL) console

kamal-rollback: .env.kamal ## Kamal : revient à une version — VERSION=<sha>
	$(KAMAL) rollback $(VERSION)
