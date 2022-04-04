include .env
export

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
TAG=$$(git log -1 --pretty=%h)

run server s:
	@echo "$(CYAN_COLOR)==> Starting rails server...$(NO_COLOR)"
	docker-compose build api && docker-compose run --service-ports api

destroy:
	@echo "$(RED_COLOR)==> Destroying all containers...$(NO_COLOR)"
	@docker rm -f `docker ps -aq`

console c:
	@echo "$(CYAN_COLOR)==> Starting rails console...$(NO_COLOR)"
	docker-compose run api rails console

migrate dbmigrate:
	@echo "$(CYAN_COLOR)==> Running database migrations...$(NO_COLOR)"
	docker-compose run --rm api_slim rake db:migrate

seed dbseed:
	@echo "$(CYAN_COLOR)==> Seeding database...$(NO_COLOR)"
	docker-compose run --rm api rake db:seed

reset r: destroy migrate seed

rspec test:
	@echo "$(CYAN_COLOR)==> Running tests...$(NO_COLOR)"
	docker-compose run --rm api_slim "rake db:test:prepare RAILS_ENV=test && rspec $(ARGS)"

rails:
	@echo "$(YELLOW_COLOR)==> Execute custom rails command...$(NO_COLOR)"
	docker-compose run --rm api_slim rails $(ARGS)

rake:
	@echo "$(YELLOW_COLOR)==> Execute custom rake command...$(NO_COLOR)"
	docker-compose run --rm api_slim rake $(ARGS)

run-docs:
	@echo "$(CYAN_COLOR)==> Starting docs server...$(NO_COLOR)"
	docker-compose up docs

gen-json-schema:
	@echo "$(CYAN_COLOR)==> Generating json-api-schema documentation...$(NO_COLOR)"
	docker-compose run --rm -T openapi2schema > spec/support/api/v1/api-schema.json
