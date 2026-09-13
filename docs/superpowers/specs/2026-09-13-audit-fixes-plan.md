# futa-recipe-app-v2 — Audit, spec et plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Appliquer les 21 corrections de l'audit à une copie du dépôt, migrer le socle (Ruby 3.3 / Rails 7.2 / PostgreSQL 16), migrer le front de CRA vers Vite, et livrer un README permettant à n'importe qui de lancer l'application en local ou de la déployer (Docker Compose sur VPS, Kamal).

**Architecture:** API Rails 7.2 `api_only` inchangée dans sa forme (route versionnée → contrôleur maigre → contrat dry-validation → service → vue jb), dont la recherche descend intégralement en SQL indexé (pg_trgm). Le front Vite est compilé dans la même image Docker et servi par Rails depuis `public/` : une seule origine en production, donc pas de CORS par défaut. La conformité HTTP est vérifiée directement contre l'OpenAPI par `committee`.

**Tech Stack:** Ruby 3.3.12 · Rails 7.2.3.2 · PostgreSQL 16 + pg_trgm · Puma 6 · dry-validation 1.11 · jb · RSpec 8 · committee-rails · React 18.3 · Vite 6.4 · Vitest 3.2 · Docker (multi-étage) · Caddy 2.11 · Kamal 2.12 · GitHub Actions

**Spec:** ce document — Partie 1 (audit) et Partie 2 (spec). Version visuelle de l'audit : https://claude.ai/code/artifact/b9c2a9bc-4ddb-4861-aede-db5e80996255

**Dépôt de travail :** `/Users/eric/Documents/DEV/PROJETS/futa-recipe-app-v2`, branche `refactor/audit-fixes` (clone de `futa-recipe-app@89f61ff`).

---

## Partie 1 — Audit : constats et tâche qui les résout

| ID | Sévérité | Constat | Résolu par |
|---|---|---|---|
| API-01 | Critique | `ApiErrors::ValidationError` et `ResourceNotFoundError` référencées mais inexistantes → `NameError` dans le gestionnaire d'erreur | Tâche 2 |
| API-02 | Critique | `GenericError` fait `details.fetch(:error_id)` en production sur une clé jamais construite → `KeyError` ; garde `Rails.env.pre_production?` morte | Tâche 2 |
| API-03 | Critique | Aucune validation : `page=0` renvoie la dernière page, `count_per_page=0` → 500, `count_per_page` non borné → DoS ; `ApplicationContract` jamais appelé | Tâche 4 |
| SEC-01 | Critique | CORS `origins '*'`, `APIKeyAuth` documentée mais absente, aucun rate limiting, `force_ssl` commenté | Tâches 1, 7 |
| PERF-01 | Critique | Recherche en mémoire Ruby : toutes les lignes `LIKE '%x%'` chargées, tri et pagination en Ruby, aucun index | Tâche 5 |
| PERF-02 | Majeur | Pagination non déterministe (`sort_by` non stable, pas de départage) | Tâche 5 |
| PERF-03 | Majeur | Correspondance par sous-chaîne : faux positifs (`egg` → `eggplant`) | Tâche 5 |
| API-04 | Majeur | `rescue_from StandardError` + `rescue` modificateurs masquent les bugs | Tâches 2, 4 |
| WEB-01 | Majeur | Changement de page : clôture périmée + décalage 0/1 → mauvaise page demandée | Tâche 9 |
| WEB-02 | Majeur | `pageCount={10}` en dur, `total_count` ignoré | Tâche 9 |
| WEB-03 | Majeur | URL d'API codée en dur vers un Heroku éteint, pas d'encodage d'URL | Tâches 8, 9 |
| OPS-01 | Majeur | `include .env` sans `.env.example`, collision `api`/`api_slim`, pas de volume Postgres, pas de `.dockerignore`, `destroy` supprime tous les conteneurs de la machine | Tâche 1 |
| QA-01 | Majeur | Test CRA par défaut en échec, aucune CI, aucun linter | Tâches 8, 12 |
| OPS-02 | Majeur | Ruby 3.0 / Rails 6.1 / PG 13 hors support, Dockerfile obsolète (Bundler 1.x, root, mono-étage) | Tâches 1, 10 |
| MOD-01 | Mineur | Modèles sans validations, sans `dependent:`/`inverse_of:`, `attribute` redondants | Tâche 6 |
| MOD-02 | Mineur | `Populator` non lotissé, non idempotent, chemin relatif au CWD | Tâche 6 |
| DOC-01 | Mineur | OpenAPI invalide (URL de base, syntaxe Swagger 2, `securitySchemes` hors `components`, pagination non documentée) | Tâche 3 |
| DEP-01 | Mineur | Gems et fichiers morts : money, money-rails, bcrypt, jsonb_accessor, pgreset, oj, spring, secrets.yml | Tâche 1 |
| QA-02 | Mineur | Couverture limitée au chemin heureux, factories irréalistes | Tâches 2 à 7, 12 |
| WEB-04 | Mineur | `ReactDOM.render` sous React 18, pas d'états chargement/erreur, champ non contrôlé sans label, `key` dupliquées | Tâches 8, 9 |
| ID-01 | Mineur | Identité « Pennylane bank », module `Src` | Tâches 1, 3, 9, 13 |

**Constat supplémentaire relevé en préparant ce plan (rattaché à DOC-01) :** la chaîne `openapi2schema` (image Node 8.15) réécrit `minimum: 0` en `minimum: -9223372036854776000` dans `spec/support/api/v1/api-schema.json`. Le test de contrat actuel ne vérifie donc plus aucune borne numérique.

---

## Partie 2 — Spec

### 2.1 Décisions validées avec l'utilisateur

- Approche **B** : saut direct de Rails 6.1 à 7.2, la suite de tests servant de filet ; les fichiers `config/environments/*` sont régénérés depuis le gabarit 7.2.3.2 (application de référence générée) plutôt que rapiécés.
- Socle **Ruby 3.3 + Rails 7.2 + PostgreSQL 16**.
- Front migré de **Create React App vers Vite**.
- **Clé d'API optionnelle** : exigée si `API_KEY` est défini, API publique sinon.
- Déploiement documenté : **Docker Compose sur un VPS** et **Kamal**.
- Copie par **`git clone` + branche** `refactor/audit-fixes`.
- Audit, spec et plan **fusionnés dans ce document unique**.

### 2.2 Décisions prises en rédigeant ce plan — à relire en priorité

Chacune affine ou remplace un point présenté plus tôt ; aucune n'a encore été validée.

1. **Ruby 3.3.12** (dernier correctif 3.3) au lieu de 3.3.8. **Vite 6.4 / Vitest 3.2 / jest-dom 6.8** au lieu des dernières majeures, qui exigent Node ≥ 20.19 ou 22 alors que la machine locale a Node 18.18. Docker et la CI utilisent Node 20.19.
2. **`committee` remplace `openapi2schema`** : les specs de requête valident la réponse réelle directement contre `docs/v1/openapi.yaml`. Plus d'étape de génération, plus de JSON dérivé périmé, et le bug de bornes ci-dessus disparaît avec la chaîne.
3. **Limitation de débit native de Rails 7.2** (`rate_limit`) au lieu de `rack-attack` : même résultat, une dépendance de moins. Limite par défaut 60 requêtes/minute/IP, compteur en mémoire par processus.
4. **Image de production unique** : le front Vite compilé est copié dans `public/` et servi par Rails. Front et API partagent la même origine ; en développement, le serveur Vite relaie `/v1` vers l'API. CORS n'est donc activé que si `CORS_ORIGINS` est renseigné, pour un client tiers.
5. **Caddy au lieu de Nginx** pour le déploiement Compose : HTTPS Let's Encrypt automatique en trois lignes de configuration, là où Nginx exige certbot et son renouvellement.
6. **`DATABASE_URL` en production uniquement.** En développement et test, `database.yml` lit `POSTGRES_HOST/PORT/USER/PASSWORD` avec des valeurs par défaut, et chaque environnement garde son propre nom de base. Rails fusionne `DATABASE_URL` dans l'environnement courant quel qu'il soit : une variable unique ferait tourner la suite de tests sur la base de développement, et `db:test:prepare` l'effacerait.
7. **`SECRET_KEY_BASE` par variable d'environnement**, et suppression de `config/credentials.yml.enc`, dont la `master.key` n'existe nulle part : ce fichier est indéchiffrable.
8. **Limite assumée de la clé d'API :** le front est public et embarqué dans la même image. Si `API_KEY` est défini, le front doit être compilé avec `VITE_API_KEY`, ce qui rend la clé lisible dans le bundle JavaScript. La clé protège donc un déploiement privé ou sans front, pas une API consommée par un navigateur public. Le README le dit explicitement.
9. **Correspondance par mot entier, avec une heuristique singulier/pluriel anglaise** (le jeu de données est en anglais). `egg` trouve `eggs` mais pas `eggplant`, `tomato` trouve `tomatoes`, `berry` trouve `berries`. Changement de comportement assumé : `berry` ne trouve plus `blueberries`, et les accents ne sont pas normalisés.
10. **Kamal n'est pas ajouté au Gemfile** : c'est un outil du poste de déploiement. La configuration est vérifiée avec l'image officielle `ghcr.io/basecamp/kamal:v2.12.0` (`kamal config`). **Aucun déploiement réel n'est effectué** : il n'y a pas de serveur cible.
11. Jeu de données déplacé de `config/data/` vers `db/data/` : ce n'est pas de la configuration.
12. Environnements `pre` et `pro` supprimés de `database.yml` : ils n'ont jamais eu de fichier `config/environments/*.rb` et ne pouvaient pas démarrer.
13. Interface conservée **en anglais** (recettes en anglais) et rebaptisée « Futa Recipes ». Documentation et README en français.
14. Service Compose `api_slim` renommé `tools` et placé derrière un profil : il ne publie aucun port et n'a pas de nom de conteneur fixe.

### 2.3 Architecture cible

```
                         ┌──────────────── image Docker unique (target: production) ────────────────┐
navigateur ──HTTPS──▶ Caddy ou kamal-proxy ──HTTP──▶ Puma / Rails 7.2                              │
                         │   GET /             → ActionDispatch::Static → public/index.html (Vite)   │
                         │   GET /up           → Rails::HealthController                            │
                         │   GET /v1/recipes/search                                                 │
                         │     → V1::AppController (Authorizable, rate_limit)                       │
                         │     → V1::RecipesController#search                                       │
                         │     → V1::Recipes::SearchContract.validate!  (422 si invalide)           │
                         │     → Recipes::IngredientList.parse                                      │
                         │     → Recipes::Searcher  ── 3 requêtes SQL indexées ──▶ PostgreSQL 16    │
                         │     → views/v1/recipes/search.json.jb                                    │
                         └──────────────────────────────────────────────────────────────────────────┘
développement : Vite :5173 ──proxy /v1──▶ Rails :3000 (conteneur api) ──▶ Postgres (conteneur db)
```

### 2.4 Contrat HTTP

`GET /v1/recipes/search`

| Paramètre | Type | Règle | Défaut |
|---|---|---|---|
| `ingredients` | chaîne, termes séparés par des virgules | chaque terme : 2 à 40 caractères, lettres Unicode, chiffres, espace, apostrophe, tiret, commençant par une lettre ou un chiffre ; 20 termes au maximum après déduplication ; absent ou vide → résultat vide | — |
| `page` | entier | ≥ 1 | 1 |
| `count_per_page` | entier | 1 à 100 | 100 |

En-tête `X-Api-Key` exigé seulement si `API_KEY` est défini côté serveur.

Réponses :
- `200` `{ "recipes": [Recipe], "page": int, "total_count": int }` — **inchangé**. `Recipe` = `{ id, name, duration_in_mins, category, result_image_url, ingredients: [string] }`.
- `401`, `422`, `429`, `500` — enveloppe unique `{ "error": { "http_code", "id", "developer_message", "details" } }` avec `id` ∈ `unauthorized`, `validation_failed`, `rate_limited`, `generic`. Pour `422`, `details.fields` contient les messages par champ. Pour `500`, `details.error_id` (UUID, également journalisé) ; `exception`, `message` et `app_traces` ne sont exposés qu'en développement et en test.

Les erreurs inattendues remontent telles quelles en développement et en test ; seule la production les convertit en `500` JSON.

### 2.5 Algorithme de recherche

Pour des termes normalisés `t₁…tₙ`, chaque terme devient un motif PostgreSQL ARE :
- `s = singularize(t)` ;
- si `s` se termine par `y` → `\m` + échappe(`s` sans le `y`) + `(y|ies)\M` ;
- sinon → `\m` + échappe(`s`) + `(s|es)?\M`.

`\m` et `\M` sont les frontières de mot de PostgreSQL. L'échappement utilise `Regexp.escape`, compatible avec les ARE pour ces caractères : c'est une défense en profondeur, le contrat ayant déjà exclu les métacaractères.

```sql
-- page de résultats : filtre indexé (ingredient_description ~* ANY (ARRAY[...]), index GIN trigramme
-- utilisé via Bitmap Index Scan), score, ordre total
SELECT recipe_id,
       bool_or(ingredient_description ~* $p1)::int + … + bool_or(ingredient_description ~* $pn)::int AS score
FROM recipe_ingredients
WHERE ingredient_description ~* ANY (ARRAY[$p1, …, $pn])
GROUP BY recipe_id
ORDER BY score DESC, recipe_id ASC
LIMIT :count_per_page OFFSET (:page - 1) * :count_per_page;

-- total
SELECT COUNT(DISTINCT recipe_id) FROM recipe_ingredients WHERE <même filtre>;

-- hydratation de la page, ordre réappliqué en Ruby sur au plus 100 identifiants
SELECT … FROM recipes WHERE id IN (…);  +  préchargement de recipe_ingredients
```

Écart assumé à l'exécution : forme `ANY` retenue pour satisfaire Brakeman, performance mesurée équivalente (≈ 3 ms).

Index : `CREATE INDEX CONCURRENTLY … USING gin (ingredient_description gin_trgm_ops)`. `gin_trgm_ops` sert `~*`, ce que ne permet pas un index B-tree.

### 2.6 Variables d'environnement

| Variable | Où | Rôle | Défaut |
|---|---|---|---|
| `POSTGRES_HOST` `POSTGRES_PORT` `POSTGRES_USER` `POSTGRES_PASSWORD` | dev, test | connexion Postgres | `localhost` `5432` `postgres` `postgres` (`db` dans Compose) |
| `DATABASE_URL` | production | connexion Postgres | — (obligatoire) |
| `SECRET_KEY_BASE` | production | clé Rails (`bin/rails secret`) | — (obligatoire) |
| `API_KEY` | toutes | active la clé d'API | vide = API publique |
| `CORS_ORIGINS` | toutes | origines tierces autorisées, séparées par des virgules | vide = CORS désactivé |
| `RATE_LIMIT_PER_MINUTE` | toutes | requêtes/minute par IP sur `/v1` | `60` |
| `FORCE_SSL` / `ASSUME_SSL` | production | redirection HTTPS / proxy TLS en amont | `true` / `true` |
| `RAILS_LOG_LEVEL` | production | niveau de journalisation | `info` |
| `API_PORT` | Compose dev | port hôte de l'API | `3000` |
| `VITE_API_URL` | build front | URL de l'API si elle n'est pas sur la même origine | vide = même origine |
| `VITE_API_KEY` | build front | clé embarquée dans le bundle (voir 2.2 §8) | vide |
| `API_PROXY_TARGET` | Vite dev | cible du proxy `/v1` | `http://localhost:3000` |

### 2.7 Hors périmètre

Normalisation des accents (`unaccent`), référentiel d'ingrédients normalisé et recherche `tsvector`, compteur de débit partagé entre processus (Redis), migration vers Rails 8, React 19, authentification par utilisateur, déploiement effectif sur un serveur.

---

## Global Constraints

- Ruby `3.3.12` (`.ruby-version`), Rails `~> 7.2.3, >= 7.2.3.2`, `config.load_defaults 7.2`, PostgreSQL `16` (`postgres:16-alpine`).
- Image Ruby de base : `ruby:3.3.12-slim` (Debian, pour un seul jeu de plateformes natives). Node en Docker et en CI : `node:20.19.5-slim` / `20.19.5`. Node local minimal : `18.18`.
- Front : `react@^18.3.1`, `vite@^6.4.3`, `vitest@^3.2.7`, `@vitejs/plugin-react@^4.7.0`, `@testing-library/jest-dom@^6.8.0`.
- Style Ruby : `rubocop-rails-omakase` (guillemets doubles, espaces dans les crochets `[ :a ]`, `%i[ a b ]`).
- Le corps de la réponse `200` de `/v1/recipes/search` reste `{ recipes, page, total_count }`, champs de `Recipe` inchangés.
- Enveloppe d'erreur unique : `{ "error": { "http_code", "id", "developer_message", "details" } }`.
- Toute commande Ruby s'exécute dans Docker (`docker compose run --rm tools …` ou cibles `make`) : la machine hôte n'a pas Ruby 3.3.12. Sur macOS, le binaire Docker est dans `~/.docker/bin`, à ajouter au `PATH` des commandes.
- **Aucun commit git** sans demande explicite de l'utilisateur (consigne globale, prioritaire sur l'étape « Commit » de la skill). Chaque tâche se termine par un point d'arrêt `git status --short` + `git diff --stat`.
- Interface utilisateur en anglais ; documentation, README et messages de commit éventuels en français.
- Aucun secret réel dans le dépôt ; seuls des fichiers `*.example` et `.kamal/secrets` (références à des variables d'environnement) sont versionnés.

---

## Carte des fichiers

**Racine et infrastructure**
- `.ruby-version` (modifié) · `Gemfile`, `Gemfile.lock` (réécrits) · `Rakefile` (inchangé)
- `Dockerfile` (réécrit, cibles `development` et `production`) · `.dockerignore` (créé) · `bin/docker-entrypoint` (créé) · `docker-entrypoint.sh` (supprimé)
- `compose.yml` (créé, remplace `docker-compose.yml`) · `compose.prod.yml` (créé) · `deploy/Caddyfile` (créé)
- `config/deploy.yml`, `.kamal/secrets`, `.env.kamal.example` (créés)
- `Makefile` (réécrit) · `.env.example`, `.env.production.example` (créés) · `.gitignore` (modifié)
- `.rspec`, `.rubocop.yml` (créés) · `bin/rails`, `bin/rake`, `bin/setup` (régénérés), `bin/rubocop`, `bin/brakeman` (créés), `bin/bundle`, `bin/spring` (supprimés)
- `.github/workflows/ci.yml`, `.github/dependabot.yml` (créés)
- `README.md` (réécrit)

**Configuration Rails**
- `config/application.rb`, `config/environments/{development,test,production}.rb`, `config/database.yml`, `config/puma.rb`, `config/routes.rb` (réécrits)
- `config/initializers/cors.rb` (réécrit) · `config/initializers/filter_parameter_logging.rb` (conservé)
- Supprimés : `config/initializers/{money,wrap_parameters,application_controller_renderer,backtrace_silencers,mime_types,inflections}.rb`, `config/{cable,storage,spring,secrets}.yml|rb`, `config/credentials.yml.enc`

**Application**
- `app/controllers/application_controller.rb` (réécrit) — traduction des exceptions en réponses JSON
- `app/controllers/concerns/authorizable.rb` (créé) — clé d'API optionnelle
- `app/controllers/v1/app_controller.rb` (modifié) — `Authorizable` + `rate_limit`
- `app/controllers/v1/recipes_controller.rb` (réécrit)
- `app/contracts/application_contract.rb` (modifié) · `app/contracts/v1/recipes/search_contract.rb` (créé)
- `app/errors/api_errors/{api_error,generic_error}.rb` (réécrits) · `{validation_error,resource_not_found_error,unauthorized_error,too_many_requests_error}.rb` (créés)
- `app/services/recipes/searcher.rb`, `populator.rb` (réécrits) · `app/services/recipes/ingredient_list.rb` (créé)
- `app/models/recipe.rb`, `recipe_ingredient.rb` (réécrits) · vues `jb` (inchangées)
- `db/migrate/20260913000001_add_trigram_index_to_recipe_ingredients.rb` (créé) · `db/schema.rb` (régénéré) · `db/seeds.rb` (modifié) · `db/data/recipes-en.json` (déplacé)

**Documentation et tests**
- `docs/v1/openapi.yaml` (réécrit, remplace `open-api-spec.yaml`) · `docs/openapi2schema/` (supprimé)
- `spec/spec_helper.rb`, `spec/rails_helper.rb` (réécrits) · `spec/support/factory_bot.rb`, `spec/support/committee.rb` (créés) · `spec/support/utils.rb`, `spec/support/api/` (supprimés)
- `spec/factories/*.rb` (réécrits) · `spec/fixtures/files/recipes-sample.json` (créé)
- Specs : `spec/controllers/application_controller_spec.rb`, `spec/errors/api_errors/*_spec.rb`, `spec/contracts/v1/recipes/search_contract_spec.rb`, `spec/services/recipes/{searcher,populator,ingredient_list}_spec.rb`, `spec/models/{recipe,recipe_ingredient}_spec.rb`, `spec/requests/v1/recipes/search_spec.rb`, `spec/requests/v1/security_spec.rb`, `spec/requests/health_spec.rb`

**Front (`web/`)**
- `package.json`, `package-lock.json` (réécrits) · `vite.config.js`, `eslint.config.js`, `index.html`, `.env.example` (créés)
- `src/main.jsx` (remplace `index.js`) · `src/App.jsx` (remplace `App.js`) · `src/App.css`, `src/index.css` (réécrits)
- `src/api/recipes.js` · `src/lib/ingredients.js` · `src/components/{IngredientForm,IngredientList,RecipeCard,SearchResults}.jsx` (créés)
- `src/test/setup.js` · `src/**/*.test.{js,jsx}` (créés)
- Supprimés : `public/index.html`, `public/manifest.json`, `public/logo192.png`, `public/logo512.png`, `src/logo.svg`, `src/reportWebVitals.js`, `src/setupTests.js`, `src/App.test.js`, `web/README.md`, `web/jsconfig.json`, `web/.gitignore`

---

## Partie 3 — Plan

Préambule de toutes les commandes shell :

```bash
export PATH="$HOME/.docker/bin:$PATH"
cd /Users/eric/Documents/DEV/PROJETS/futa-recipe-app-v2
```

### Task 1: Socle Ruby 3.3.12 / Rails 7.2 / PostgreSQL 16 démarrable dans Docker (OPS-01, OPS-02, DEP-01, SEC-01 partiel, ID-01 partiel)

Objectif : l'application existante, **sans changement de comportement**, démarre et passe ses 7 examples actuels sur le nouveau socle. C'est le filet de toutes les tâches suivantes.

**Files:**
- Delete: `config/initializers/{money,wrap_parameters,application_controller_renderer,backtrace_silencers,mime_types,inflections}.rb`, `config/cable.yml`, `config/storage.yml`, `config/spring.rb`, `config/secrets.yml`, `config/credentials.yml.enc`, `bin/bundle`, `bin/spring`, `docker-entrypoint.sh`, `docker-compose.yml`, `Dockerfile`
- Create: `.dockerignore`, `bin/docker-entrypoint`, `compose.yml`, `.env.example`
- Modify: `.ruby-version`, `Gemfile`, `Gemfile.lock`, `Makefile`, `.gitignore`, `bin/rails`, `bin/rake`, `bin/setup`, `config/application.rb`, `config/environments/{development,test,production}.rb`, `config/database.yml`, `config/puma.rb`, `config/routes.rb`, `spec/rails_helper.rb`
- Test: `spec/requests/health_spec.rb`

**Interfaces:**
- Consumes: rien.
- Produces: module applicatif `FutaRecipes` ; service Compose `api` (serveur, port `${API_PORT:-3000}`) et `tools` (commandes ponctuelles, profil `tools`) ; cibles `make setup|build|up|down|destroy|console|shell|migrate|seed|reset|test` ; variable `ARGS` pour `make test` ; route `GET /up`.

- [ ] **Step 1: Supprimer les fichiers morts**

```bash
git rm -q config/initializers/money.rb config/initializers/wrap_parameters.rb \
  config/initializers/application_controller_renderer.rb config/initializers/backtrace_silencers.rb \
  config/initializers/mime_types.rb config/initializers/inflections.rb \
  config/cable.yml config/storage.yml config/spring.rb config/secrets.yml config/credentials.yml.enc \
  bin/bundle bin/spring docker-entrypoint.sh docker-compose.yml Dockerfile
```

- [ ] **Step 2: Fixer la version de Ruby et réécrire le Gemfile**

`.ruby-version` :
```
3.3.12
```

`Gemfile` (faker et json-schema restent temporairement pour les specs existantes ; ils partent aux tâches 3 et 6) :
```ruby
source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 7.2.3", ">= 7.2.3.2"
gem "pg", "~> 1.6"
gem "puma", "~> 6.6"
gem "bootsnap", require: false
gem "dry-validation", "~> 1.11"
gem "jb", "~> 0.8.2"
gem "rack-cors", "~> 3.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.8"
  gem "rspec-rails", "~> 8.0"
end

group :test do
  gem "json-schema", "~> 6.2"
  gem "rspec_junit_formatter", "~> 0.6"
end
```

- [ ] **Step 3: Générer le Gemfile.lock pour les plateformes Linux**

```bash
rm -f Gemfile.lock
docker run --rm -v "$PWD:/rails" -w /rails ruby:3.3.12-slim \
  bash -c "bundle lock --add-platform x86_64-linux aarch64-linux && bundle lock --remove-platform ruby || true"
grep -A3 "^PLATFORMS" Gemfile.lock
grep -A1 "^BUNDLED WITH" Gemfile.lock
```
Expected: `PLATFORMS` liste `aarch64-linux` et `x86_64-linux` ; `BUNDLED WITH` est une version 2.x.

- [ ] **Step 4: Régénérer les binstubs**

`bin/rails` :
```ruby
#!/usr/bin/env ruby
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require "rails/commands"
```

`bin/rake` :
```ruby
#!/usr/bin/env ruby
require_relative "../config/boot"
require "rake"
Rake.application.run
```

`bin/setup` :
```ruby
#!/usr/bin/env ruby
require "fileutils"

APP_ROOT = File.expand_path("..", __dir__)

def system!(*args)
  system(*args, exception: true)
end

FileUtils.chdir APP_ROOT do
  puts "== Installing dependencies =="
  system("bundle check") || system!("bundle install")

  puts "\n== Preparing database =="
  system! "bin/rails db:prepare"

  puts "\n== Removing old logs and tempfiles =="
  system! "bin/rails log:clear tmp:clear"
end
```

`bin/docker-entrypoint` :
```bash
#!/bin/bash -e

# jemalloc réduit la fragmentation mémoire de Ruby.
if [ -z "${LD_PRELOAD+x}" ] && [ -f /usr/lib/*/libjemalloc.so.2 ]; then
  export LD_PRELOAD="$(echo /usr/lib/*/libjemalloc.so.2)"
fi

if [ "${1}" == "./bin/rails" ] && [ "${2}" == "server" ]; then
  # Un arrêt brutal du conteneur laisse ce fichier derrière lui et bloque le redémarrage.
  rm -f tmp/pids/server.pid
  ./bin/rails db:prepare
fi

exec "${@}"
```

```bash
chmod +x bin/rails bin/rake bin/setup bin/docker-entrypoint
```

- [ ] **Step 5: Réécrire la configuration Rails**

`config/application.rb` :
```ruby
require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module FutaRecipes
  class Application < Rails::Application
    config.load_defaults 7.2
    config.autoload_lib(ignore: %w[ assets tasks ])
    config.api_only = true
  end
end
```

`config/environments/development.rb` :
```ruby
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.cache_store = :memory_store
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  config.action_controller.raise_on_missing_callback_actions = true
end
```

`config/environments/test.rb` :
```ruby
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.action_controller.raise_on_missing_callback_actions = true
end
```

`config/environments/production.rb` :
```ruby
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # TLS terminé par un proxy (Caddy ou kamal-proxy). FORCE_SSL=false permet un essai en HTTP pur.
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "true") == "true"
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  config.log_tags = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
```

`config/database.yml` :
```yaml
# Développement et test : connexion par variables séparées, une base par environnement.
# Production : DATABASE_URL uniquement. Ne jamais définir DATABASE_URL en développement :
# Rails l'appliquerait aussi à l'environnement de test, qui écraserait alors la base de développement.
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  host: <%= ENV.fetch("POSTGRES_HOST", "localhost") %>
  port: <%= ENV.fetch("POSTGRES_PORT", 5432) %>
  username: <%= ENV.fetch("POSTGRES_USER", "postgres") %>
  password: <%= ENV.fetch("POSTGRES_PASSWORD", "postgres") %>

development:
  <<: *default
  database: futa_recipes_development

test:
  <<: *default
  database: futa_recipes_test

production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  url: <%= ENV["DATABASE_URL"] %>
```

`config/puma.rb` :
```ruby
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
```

`config/routes.rb` :
```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :v1, defaults: { format: :json } do
    resources :recipes, only: [] do
      get :search, on: :collection
    end
  end
end
```

Dans `spec/rails_helper.rb`, supprimer la ligne `config.fixture_path = "#{::Rails.root}/spec/fixtures"` (retirée de rspec-rails 7 ; le projet n'utilise pas de fixtures).

- [ ] **Step 6: Écrire la spec de santé (échoue tant que l'image n'existe pas)**

`spec/requests/health_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe "GET /up", type: :request do
  it "répond 200 quand l'application a démarré" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
```

- [ ] **Step 7: Écrire l'outillage Docker**

`Dockerfile` :
```dockerfile
# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3.12

# ---------- base commune ----------
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
ENV BUNDLE_PATH="/usr/local/bundle"

FROM base AS build-deps
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ---------- développement et tests (docker compose) ----------
FROM build-deps AS development
ENV RAILS_ENV="development"
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 --retry 3
COPY . .
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

# ---------- compilation production ----------
FROM build-deps AS build
ENV RAILS_ENV="production" BUNDLE_DEPLOYMENT="1" BUNDLE_WITHOUT="development:test"
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile
COPY . .
RUN bundle exec bootsnap precompile app/ lib/

# ---------- image finale (cible par défaut : dernière étape) ----------
FROM base AS production
ENV RAILS_ENV="production" BUNDLE_DEPLOYMENT="1" BUNDLE_WITHOUT="development:test"
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server"]
```

`.dockerignore` :
```
/.git/
/.github/
/.kamal/
/.env*
/config/master.key
/log/*
!/log/.keep
/tmp/*
!/tmp/.keep
/coverage/
/web/node_modules/
/web/dist/
/docs/superpowers/
/Dockerfile
/.dockerignore
/compose*.yml
```

`compose.yml` :
```yaml
name: futa-recipes

x-app: &app
  build:
    context: .
    target: development
  image: futa-recipes:development
  env_file:
    - path: .env
      required: false
  environment:
    POSTGRES_HOST: db
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
  volumes:
    - .:/rails
  depends_on:
    db:
      condition: service_healthy

services:
  api:
    <<: *app
    ports:
      - "${API_PORT:-3000}:3000"
    tty: true
    stdin_open: true

  # Commandes ponctuelles (console, migrations, tests) : aucun port publié, aucun nom fixe.
  tools:
    <<: *app
    profiles: [ "tools" ]
    command: [ "bash" ]

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U postgres" ]
      interval: 2s
      timeout: 3s
      retries: 30

volumes:
  pgdata:
```

`.env.example` :
```
# Copier en .env pour surcharger les valeurs de développement (fichier optionnel).
API_PORT=3000
# API_KEY=
# CORS_ORIGINS=
# RATE_LIMIT_PER_MINUTE=60
```

`Makefile` (indentation par tabulations) :
```make
COMPOSE ?= docker compose
RUN     := $(COMPOSE) run --rm tools
ARGS    ?=

.DEFAULT_GOAL := help
.PHONY: help setup build up down destroy console shell migrate seed reset test

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
	$(COMPOSE) run --rm -e RAILS_ENV=test tools bash -c "bin/rails db:create db:schema:load && bundle exec rspec $(ARGS)"
```

Dans `.gitignore`, remplacer le bloc final (de `.env` à `/web/.env.production.*`) par :
```
/.env
/.env.production
/.env.kamal
/coverage/
/spec/examples.txt
.DS_Store

/web/node_modules/
/web/dist/
/web/.env.local
/web/.env.*.local
```

- [ ] **Step 8: Construire et amorcer**

```bash
make setup
docker compose run --rm tools bin/rails runner 'puts [Recipe.count, RecipeIngredient.count].inspect'
```
Expected: `db:prepare` crée la base, charge le schéma et exécute les seeds ; la dernière commande affiche `[10013, 96417]`. Si `db:prepare` n'a pas amorcé, lancer `make seed` puis relancer la vérification.

- [ ] **Step 9: Faire passer la suite existante**

Run: `make test`
Expected: `8 examples, 0 failures` (7 existants + santé). Toute dépréciation levée par `disallowed_deprecation = :raise` doit être corrigée dans le code, pas désactivée.

- [ ] **Step 10: Vérifier le serveur**

```bash
docker compose up -d api
until curl -fsS http://localhost:3000/up >/dev/null; do sleep 2; done
curl -s "http://localhost:3000/v1/recipes/search?ingredients=rice&count_per_page=2" | head -c 300; echo
docker compose down
```
Expected: `/up` répond ; la recherche renvoie un JSON `{"recipes":[…],"page":1,"total_count":…}`.

- [ ] **Step 11: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 2: Erreurs d'API fiables (API-01, API-02, API-04)

**Files:**
- Modify: `app/errors/api_errors/api_error.rb`, `app/errors/api_errors/generic_error.rb`, `app/controllers/application_controller.rb`
- Create: `app/errors/api_errors/resource_not_found_error.rb`, `app/errors/api_errors/validation_error.rb`
- Test: `spec/errors/api_errors/api_error_spec.rb`, `spec/errors/api_errors/generic_error_spec.rb`, `spec/controllers/application_controller_spec.rb`

**Interfaces:**
- Consumes: socle de la tâche 1.
- Produces:
  - `ApiErrors::ApiError.new(http_code:, id:, developer_message:, details: {})`, lecteurs du même nom, `#as_json` → `{ http_code:, id:, developer_message:, details: }` (clés symboles, dans cet ordre).
  - `ApiErrors::GenericError.new(exception: nil, error_id: SecureRandom.uuid, expose_internals: Rails.env.local?)` → 500, `id: "generic"`, `#error_id`.
  - `ApiErrors::ResourceNotFoundError.new(message = "Resource not found")` → 404, `id: "resource_not_found"`, `details: { message: }`.
  - `ApiErrors::ValidationError.new(fields)` → 422, `id: "validation_failed"`, `details: { fields: }`.
  - `ApplicationController.render_unexpected_errors` (`class_attribute`, défaut `Rails.env.production?`) ; méthode privée `render_api_error(error)`.

- [ ] **Step 1: Écrire les specs d'erreurs**

`spec/errors/api_errors/api_error_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe ApiErrors::ApiError do
  it "sérialise chaque sous-classe avec l'enveloppe commune (régression API-01)" do
    errors = [
      ApiErrors::GenericError.new,
      ApiErrors::ResourceNotFoundError.new("Couldn't find Recipe"),
      ApiErrors::ValidationError.new(page: [ "must be greater than or equal to 1" ])
    ]

    expect(errors.map { |error| error.as_json.keys }.uniq).to eq([ %i[ http_code id developer_message details ] ])
    expect(errors.map(&:http_code)).to eq([ 500, 404, 422 ])
    expect(errors.map(&:id)).to eq(%w[ generic resource_not_found validation_failed ])
  end

  it "utilise developer_message comme message d'exception" do
    expect(ApiErrors::ResourceNotFoundError.new.message).to eq("The requested resource does not exist")
  end
end
```

`spec/errors/api_errors/generic_error_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe ApiErrors::GenericError do
  let(:exception) do
    RuntimeError.new("boom").tap { |error| error.set_backtrace([ "#{Rails.root}/app/models/recipe.rb:1" ]) }
  end

  it "ne lève rien sans exception d'origine (régression API-02)" do
    expect { described_class.new(expose_internals: false) }.not_to raise_error
  end

  it "n'expose que l'error_id quand expose_internals est faux" do
    error = described_class.new(exception:, expose_internals: false)

    expect(error.details.keys).to eq([ :error_id ])
    expect(error.error_id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  it "expose l'exception nettoyée quand expose_internals est vrai" do
    error = described_class.new(exception:, expose_internals: true)

    expect(error.details).to include(error_id: error.error_id, exception: "RuntimeError", message: "boom")
    expect(error.details[:app_traces]).to eq([ "app/models/recipe.rb:1" ])
  end
end
```

`spec/controllers/application_controller_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller(described_class) do
    def not_found = raise(ActiveRecord::RecordNotFound, "Couldn't find Recipe")
    def invalid = raise(ApiErrors::ValidationError.new(page: [ "must be greater than or equal to 1" ]))
    def boom = raise(ArgumentError, "boom")
  end

  before do
    routes.draw do
      get "not_found" => "anonymous#not_found"
      get "invalid" => "anonymous#invalid"
      get "boom" => "anonymous#boom"
    end
  end

  let(:error) { JSON.parse(response.body).fetch("error") }

  it "traduit RecordNotFound en 404 JSON" do
    get :not_found

    expect(response).to have_http_status(404)
    expect(error).to include("id" => "resource_not_found", "http_code" => 404)
  end

  it "rend une ApiError avec son propre code" do
    get :invalid

    expect(response).to have_http_status(422)
    expect(error["details"]).to eq("fields" => { "page" => [ "must be greater than or equal to 1" ] })
  end

  context "hors production" do
    it "laisse remonter les exceptions imprévues (régression API-04)" do
      expect { get :boom }.to raise_error(ArgumentError, "boom")
    end
  end

  context "en production" do
    around do |example|
      self.class.controller_class.render_unexpected_errors = true
      example.run
    ensure
      self.class.controller_class.render_unexpected_errors = false
    end

    it "rend un 500 JSON et journalise l'error_id" do
      allow(Rails.logger).to receive(:error)

      get :boom

      expect(response).to have_http_status(500)
      expect(error).to include("id" => "generic", "http_code" => 500)
      expect(Rails.logger).to have_received(:error).with(a_string_including(error.dig("details", "error_id")))
    end
  end
end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `make test ARGS="spec/errors spec/controllers"`
Expected: FAIL — `NameError: uninitialized constant ApiErrors::ResourceNotFoundError` (le bug API-01 lui-même).

- [ ] **Step 3: Implémenter les erreurs**

`app/errors/api_errors/api_error.rb` :
```ruby
module ApiErrors
  # Erreur métier sérialisée telle quelle dans { "error": … }.
  class ApiError < StandardError
    attr_reader :http_code, :id, :developer_message, :details

    def initialize(http_code:, id:, developer_message:, details: {})
      @http_code = http_code
      @id = id
      @developer_message = developer_message
      @details = details
      super(developer_message)
    end

    def as_json(*)
      { http_code:, id:, developer_message:, details: }
    end
  end
end
```

`app/errors/api_errors/generic_error.rb` :
```ruby
module ApiErrors
  # Erreur imprévue. Le client ne reçoit que l'error_id, qui permet de retrouver la trace dans les logs.
  class GenericError < ApiError
    attr_reader :error_id

    def initialize(exception: nil, error_id: SecureRandom.uuid, expose_internals: Rails.env.local?)
      @error_id = error_id
      details = { error_id: }

      if expose_internals && exception
        details.merge!(
          exception: exception.class.name,
          message: exception.message,
          app_traces: Rails.backtrace_cleaner.clean(exception.backtrace || [])
        )
      end

      super(
        http_code: 500,
        id: "generic",
        developer_message: "Unexpected server error. Quote the error_id when reporting it.",
        details:
      )
    end
  end
end
```

`app/errors/api_errors/resource_not_found_error.rb` :
```ruby
module ApiErrors
  class ResourceNotFoundError < ApiError
    def initialize(message = "Resource not found")
      super(
        http_code: 404,
        id: "resource_not_found",
        developer_message: "The requested resource does not exist",
        details: { message: }
      )
    end
  end
end
```

`app/errors/api_errors/validation_error.rb` :
```ruby
module ApiErrors
  class ValidationError < ApiError
    # fields - Hash { champ => [messages] } tel que produit par dry-validation.
    def initialize(fields)
      super(
        http_code: 422,
        id: "validation_failed",
        developer_message: "One or more parameters are invalid",
        details: { fields: }
      )
    end
  end
end
```

`app/controllers/application_controller.rb` :
```ruby
class ApplicationController < ActionController::API
  # En production, une exception imprévue devient un 500 JSON journalisé.
  # En développement et en test, elle remonte pour être vue là où elle naît.
  class_attribute :render_unexpected_errors, default: Rails.env.production?

  # rescue_from teste les gestionnaires du dernier déclaré au premier.
  rescue_from StandardError, with: :handle_unexpected_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from ApiErrors::ApiError, with: :render_api_error

  private

  def handle_unexpected_error(exception)
    raise exception unless render_unexpected_errors

    error = ApiErrors::GenericError.new(exception:)
    Rails.logger.error(
      {
        error_id: error.error_id,
        exception: exception.class.name,
        message: exception.message,
        backtrace: Array(exception.backtrace).first(20)
      }.to_json
    )
    render_api_error(error)
  end

  def handle_record_not_found(exception)
    render_api_error(ApiErrors::ResourceNotFoundError.new(exception.message))
  end

  def render_api_error(error)
    render json: { error: }, status: error.http_code
  end
end
```

- [ ] **Step 4: Vérifier le succès et la non-régression**

Run: `make test`
Expected: `17 examples, 0 failures` (8 de la tâche 1 + 9 nouveaux).

- [ ] **Step 5: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 3: OpenAPI valide et tests de contrat par committee (DOC-01)

Le contrat est écrit en premier : les tâches 4 à 7 implémentent des réponses déjà documentées et vérifiées.

**Files:**
- Delete: `docs/openapi2schema/Dockerfile`, `docs/v1/open-api-spec.yaml`, `spec/support/utils.rb`, `spec/support/api/schema_matcher.rb`, `spec/support/api/factory_bot.rb`, `spec/support/api/v1/api-schema.json`
- Create: `docs/v1/openapi.yaml`, `spec/support/committee.rb`, `spec/support/factory_bot.rb`, `.rspec`
- Modify: `Gemfile`, `Gemfile.lock`, `spec/spec_helper.rb`, `spec/rails_helper.rb`, `spec/requests/v1/recipes/search_spec.rb`, `spec/services/recipes/searcher_spec.rb` (ligne `describe` uniquement), `compose.yml`, `Makefile`
- Test: `spec/requests/v1/recipes/search_spec.rb`

**Interfaces:**
- Consumes: enveloppe d'erreur de la tâche 2.
- Produces: `docs/v1/openapi.yaml` (schémas `Recipe`, `SearchResult`, `Error`, `ErrorEnvelope` ; réponses `Unauthorized`, `ValidationFailed`, `RateLimited`, `UnexpectedError`) ; helper de spec `assert_response_schema_confirm(status)` disponible dans toutes les specs `type: :request` ; cibles `make docs` et `make docs-lint`.

- [ ] **Step 1: Remplacer json-schema par committee-rails**

Dans `Gemfile`, groupe `:test`, remplacer `gem "json-schema", "~> 6.2"` par :
```ruby
  gem "committee-rails", "~> 0.10"
```

```bash
docker compose run --rm tools bundle lock
make build
```
Expected: `Gemfile.lock` contient `committee-rails (0.10.x)`, `committee (5.x)`, et plus `json-schema`.

- [ ] **Step 2: Supprimer la chaîne openapi2schema**

```bash
git rm -q -r docs/openapi2schema docs/v1/open-api-spec.yaml spec/support/utils.rb spec/support/api
```

- [ ] **Step 3: Écrire la spécification OpenAPI**

`docs/v1/openapi.yaml` :
```yaml
openapi: 3.0.3

info:
  title: Futa Recipes API
  version: 1.0.0
  description: |
    Recherche de recettes à partir des ingrédients dont on dispose.

    Les recettes sont classées par nombre d'ingrédients recherchés qu'elles contiennent,
    puis par identifiant, ce qui garantit une pagination stable.

    ## Authentification
    L'API est publique par défaut. Si le serveur définit `API_KEY`, chaque requête
    doit porter l'en-tête `X-Api-Key`.

    ## Limitation de débit
    60 requêtes par minute et par adresse IP par défaut (variable `RATE_LIMIT_PER_MINUTE`).

servers:
  - url: http://localhost:3000/v1
    description: Développement local
  - url: /v1
    description: Même origine que le front déployé

tags:
  - name: recipes
    description: Recherche de recettes

security:
  - {}
  - ApiKeyAuth: []

paths:
  /recipes/search:
    get:
      tags: [ recipes ]
      operationId: searchRecipes
      summary: Rechercher des recettes par ingrédients
      description: |
        Chaque terme est comparé en mot entier, sans tenir compte de la casse, au singulier
        comme au pluriel anglais : `egg` trouve « 2 large eggs » mais pas « 1 eggplant ».
      parameters:
        - name: ingredients
          in: query
          required: false
          description: |
            Termes séparés par des virgules. Chaque terme compte de 2 à 40 caractères
            (lettres, chiffres, espace, apostrophe, tiret) et commence par une lettre ou un chiffre.
            20 termes au maximum après déduplication. Absent ou vide : résultat vide.
          schema:
            type: string
          example: rice,bread
        - name: page
          in: query
          required: false
          schema:
            type: integer
            minimum: 1
            default: 1
        - name: count_per_page
          in: query
          required: false
          schema:
            type: integer
            minimum: 1
            maximum: 100
            default: 100
      responses:
        "200":
          description: Page de résultats
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/SearchResult"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "422":
          $ref: "#/components/responses/ValidationFailed"
        "429":
          $ref: "#/components/responses/RateLimited"
        "500":
          $ref: "#/components/responses/UnexpectedError"

components:
  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-Api-Key

  schemas:
    Recipe:
      type: object
      additionalProperties: false
      required: [ id, name, duration_in_mins, category, result_image_url, ingredients ]
      properties:
        id:
          type: string
          format: uuid
          example: 3f0e4f7a-1c9b-4d2e-9a51-0b6c2f8d7e41
        name:
          type: string
          example: Golden Sweet Cornbread
        duration_in_mins:
          type: integer
          minimum: 0
          example: 35
        category:
          type: string
          description: Peut être une chaîne vide.
          example: Cornbread
        result_image_url:
          type: string
          example: https://imagesvc.meredithcorp.io/v3/mm/image?url=cornbread.jpg
        ingredients:
          type: array
          items:
            type: string
          example: [ "1 cup all-purpose flour", "1 cup yellow cornmeal" ]

    SearchResult:
      type: object
      additionalProperties: false
      required: [ recipes, page, total_count ]
      properties:
        recipes:
          type: array
          items:
            $ref: "#/components/schemas/Recipe"
        page:
          type: integer
          minimum: 1
        total_count:
          type: integer
          minimum: 0

    Error:
      type: object
      additionalProperties: false
      required: [ http_code, id, developer_message, details ]
      properties:
        http_code:
          type: integer
        id:
          type: string
          enum: [ unauthorized, validation_failed, rate_limited, resource_not_found, generic ]
        developer_message:
          type: string
        details:
          type: object
          description: |
            `validation_failed` : `{ "fields": { "<champ>": ["<message>"] } }`.
            `generic` : `{ "error_id": "<uuid>" }`, à citer lors d'un signalement.

    ErrorEnvelope:
      type: object
      additionalProperties: false
      required: [ error ]
      properties:
        error:
          $ref: "#/components/schemas/Error"

  responses:
    Unauthorized:
      description: Clé d'API absente ou invalide (uniquement si le serveur définit `API_KEY`)
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
          example:
            error: { http_code: 401, id: unauthorized, developer_message: A valid X-Api-Key header is required, details: {} }
    ValidationFailed:
      description: Paramètre invalide
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
          example:
            error:
              http_code: 422
              id: validation_failed
              developer_message: One or more parameters are invalid
              details: { fields: { page: [ "must be greater than or equal to 1" ] } }
    RateLimited:
      description: Trop de requêtes pour cette adresse IP
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
          example:
            error: { http_code: 429, id: rate_limited, developer_message: Too many requests, retry in a minute, details: {} }
    UnexpectedError:
      description: Erreur serveur imprévue
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
          example:
            error:
              http_code: 500
              id: generic
              developer_message: Unexpected server error. Quote the error_id when reporting it.
              details: { error_id: 8b1f6c2e-2d7a-4f0e-9a3b-5c4d1e2f3a4b }
```

- [ ] **Step 4: Ajouter la documentation Redoc et le lint**

Dans `compose.yml`, sous `services:` :
```yaml
  docs:
    image: redocly/redoc:v2.5.3
    profiles: [ "docs" ]
    ports:
      - "${DOCS_PORT:-8080}:80"
    volumes:
      - ./docs/v1/openapi.yaml:/usr/share/nginx/html/openapi.yaml:ro
    environment:
      SPEC_URL: openapi.yaml
```

Dans `Makefile`, ajouter `docs docs-lint` à `.PHONY` et :
```make
docs: ## Documentation de l'API sur http://localhost:8080
	$(COMPOSE) --profile docs up docs

docs-lint: ## Valide docs/v1/openapi.yaml
	npx --yes @redocly/cli@1.34.20 lint docs/v1/openapi.yaml
```

Run: `make docs-lint`
Expected: `Woohoo! Your API description is valid.` — des avertissements sont acceptables, aucune erreur.

- [ ] **Step 5: Réécrire l'outillage RSpec**

`.rspec` :
```
--require spec_helper
```

`spec/spec_helper.rb` :
```ruby
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
```

`spec/rails_helper.rb` :
```ruby
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
```

`spec/support/factory_bot.rb` :
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

`spec/support/committee.rb` :
```ruby
# Les réponses réelles sont validées directement contre docs/v1/openapi.yaml.
RSpec.configure do |config|
  config.add_setting :committee_options
  config.committee_options = {
    schema_path: Rails.root.join("docs/v1/openapi.yaml").to_s,
    prefix: "/v1",
    strict_reference_validation: true,
    parse_response_by_content_type: true
  }

  config.include Committee::Rails::Test::Methods, type: :request
end
```

`disable_monkey_patching!` interdit le `describe` nu : dans `spec/services/recipes/searcher_spec.rb`, remplacer la première ligne `describe Recipes::Searcher do` par `RSpec.describe Recipes::Searcher do`.

- [ ] **Step 6: Réécrire la spec de requête avec le contrat**

`spec/requests/v1/recipes/search_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe "GET /v1/recipes/search", type: :request do
  let(:body) { JSON.parse(response.body) }

  before do
    create(:recipe, name: "Rice pudding").tap do |recipe|
      [ "1/2 cup of rice", "half bread", "1 cup water" ].each do |description|
        create(:recipe_ingredient, recipe:, ingredient_description: description)
      end
    end
  end

  it "renvoie une page conforme à l'OpenAPI" do
    get "/v1/recipes/search", params: { ingredients: "rice,bread", page: 1, count_per_page: 10 }

    expect(response).to have_http_status(200)
    assert_response_schema_confirm(200)
    expect(body["total_count"]).to eq(1)
  end

  it "accepte l'absence de tout paramètre" do
    get "/v1/recipes/search"

    assert_response_schema_confirm(200)
    expect(body).to eq("recipes" => [], "page" => 1, "total_count" => 0)
  end

  it "accepte l'absence de count_per_page" do
    get "/v1/recipes/search", params: { ingredients: "rice,bread", page: 1 }

    assert_response_schema_confirm(200)
  end
end
```

- [ ] **Step 7: Vérifier que le contrat mord**

```bash
sed -i.bak '/category: recipe.category,/d' app/views/v1/recipes/_recipe.json.jb
make test ARGS="spec/requests/v1/recipes/search_spec.rb"
mv app/views/v1/recipes/_recipe.json.jb.bak app/views/v1/recipes/_recipe.json.jb
git diff --quiet -- app/views && echo "vue restaurée"
```
Expected: FAIL avec un message committee signalant la propriété requise `category` manquante ; puis `vue restaurée`.

- [ ] **Step 8: Suite complète**

Run: `make test`
Expected: `17 examples, 0 failures` (ordre aléatoire, graine affichée).

- [ ] **Step 9: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 4: Validation des paramètres de recherche (API-03, API-04)

**Files:**
- Create: `app/services/recipes/ingredient_list.rb`, `app/contracts/v1/recipes/search_contract.rb`
- Modify: `app/contracts/application_contract.rb`, `app/controllers/v1/recipes_controller.rb`, `spec/requests/v1/recipes/search_spec.rb`
- Test: `spec/services/recipes/ingredient_list_spec.rb`, `spec/contracts/v1/recipes/search_contract_spec.rb`

**Interfaces:**
- Consumes: `ApiErrors::ValidationError.new(fields)` (tâche 2), `assert_response_schema_confirm` (tâche 3).
- Produces:
  - `Recipes::IngredientList.parse(raw) → Array<String>` : découpe sur `,`, `squish`, `downcase`, retire les vides, déduplique ; `nil` → `[]`.
  - `V1::Recipes::SearchContract` (`MAX_INGREDIENTS = 20`, `MAX_COUNT_PER_PAGE = 100`, `INGREDIENT_FORMAT`) ; `ApplicationContract.validate!(hash) → Hash` à clés symboles, ou lève `ApiErrors::ValidationError`.
  - `Recipes::Searcher.new(ingredients: Array<String>, page: Integer | nil, count_per_page: Integer | nil)` reçoit désormais des valeurs déjà validées.

- [ ] **Step 1: Écrire les specs du parseur et du contrat**

`spec/services/recipes/ingredient_list_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe Recipes::IngredientList do
  it "découpe, normalise, déduplique et ignore les termes vides" do
    expect(described_class.parse("  Rice, BREAD ,, rice , white   rice")).to eq([ "rice", "bread", "white rice" ])
  end

  it "met en minuscules les caractères accentués" do
    expect(described_class.parse("CRÈME Fraîche")).to eq([ "crème fraîche" ])
  end

  it "renvoie une liste vide pour nil ou une chaîne vide" do
    expect(described_class.parse(nil)).to eq([])
    expect(described_class.parse("")).to eq([])
  end
end
```

`spec/contracts/v1/recipes/search_contract_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe V1::Recipes::SearchContract do
  def call(params) = described_class.new.call(params)

  it "accepte des paramètres valides et convertit les entiers" do
    result = call("ingredients" => "rice, crème fraîche, sour-dough, chef's salt", "page" => "2", "count_per_page" => "100")

    expect(result).to be_success
    expect(result.to_h).to eq(ingredients: "rice, crème fraîche, sour-dough, chef's salt", page: 2, count_per_page: 100)
  end

  it "accepte l'absence de paramètres et une liste d'ingrédients vide" do
    expect(call({})).to be_success
    expect(call("ingredients" => "")).to be_success
  end

  it "compte les ingrédients après déduplication" do
    expect(call("ingredients" => ([ "rice" ] * 30).join(","))).to be_success
  end

  {
    { "page" => "0" } => { page: [ "must be greater than or equal to 1" ] },
    { "page" => "-2" } => { page: [ "must be greater than or equal to 1" ] },
    { "page" => "abc" } => { page: [ "must be an integer" ] },
    { "count_per_page" => "0" } => { count_per_page: [ "must be greater than or equal to 1" ] },
    { "count_per_page" => "101" } => { count_per_page: [ "must be less than or equal to 100" ] },
    { "ingredients" => "rice;drop table" } => { ingredients: [ "contains invalid ingredients: rice;drop table" ] },
    { "ingredients" => "rice,r" } => { ingredients: [ "contains invalid ingredients: r" ] },
    { "ingredients" => "egg.*" } => { ingredients: [ "contains invalid ingredients: egg.*" ] },
    { "ingredients" => "-rice" } => { ingredients: [ "contains invalid ingredients: -rice" ] }
  }.each do |params, errors|
    it "rejette #{params.inspect}" do
      expect(call(params).errors.to_h).to eq(errors)
    end
  end

  it "rejette plus de 20 ingrédients distincts" do
    terms = (1..21).map { |n| "ingredient #{n}" }.join(",")

    expect(call("ingredients" => terms).errors.to_h).to eq(ingredients: [ "must contain at most 20 ingredients" ])
  end

  it "tronque la liste des termes invalides renvoyée au client" do
    terms = (1..8).map { |n| "bad;#{n}" }.join(",")

    expect(call("ingredients" => terms).errors.to_h[:ingredients].first)
      .to eq("contains invalid ingredients: bad;1, bad;2, bad;3, bad;4, bad;5")
  end
end
```

- [ ] **Step 2: Ajouter les régressions HTTP**

Dans `spec/requests/v1/recipes/search_spec.rb`, avant le `end` final :
```ruby
  describe "paramètres invalides (régressions API-03)" do
    {
      "page=0 ne renvoie plus la dernière page" => { page: 0 },
      "count_per_page=0 ne provoque plus de 500" => { count_per_page: 0 },
      "count_per_page est borné à 100" => { count_per_page: 10_000_000 },
      "les métacaractères d'expression régulière sont refusés" => { ingredients: "rice.*" }
    }.each do |label, invalid_params|
      it label do
        get "/v1/recipes/search", params: { ingredients: "rice" }.merge(invalid_params)

        expect(response).to have_http_status(422)
        assert_response_schema_confirm(422)
        expect(body.dig("error", "id")).to eq("validation_failed")
      end
    end
  end
```

- [ ] **Step 3: Vérifier l'échec**

Run: `make test ARGS="spec/services/recipes/ingredient_list_spec.rb spec/contracts spec/requests"`
Expected: FAIL — `NameError: uninitialized constant Recipes::IngredientList` et `V1::Recipes`, et les 4 régressions HTTP échouent (200 ou 500 au lieu de 422).

- [ ] **Step 4: Implémenter**

`app/services/recipes/ingredient_list.rb` :
```ruby
module Recipes
  # Transforme la saisie brute "Rice, bread,,rice" en [ "rice", "bread" ].
  module IngredientList
    SEPARATOR = ","

    def self.parse(raw)
      raw.to_s.split(SEPARATOR).map { |term| term.squish.downcase }.compact_blank.uniq
    end
  end
end
```

`app/contracts/application_contract.rb` :
```ruby
class ApplicationContract < Dry::Validation::Contract
  # Renvoie les paramètres convertis (clés symboles) ou lève ApiErrors::ValidationError.
  def self.validate!(data)
    result = new.call(data)
    raise ApiErrors::ValidationError.new(result.errors.to_h) unless result.success?

    result.to_h
  end
end
```

`app/contracts/v1/recipes/search_contract.rb` :
```ruby
module V1
  module Recipes
    class SearchContract < ApplicationContract
      MAX_INGREDIENTS = 20
      MAX_COUNT_PER_PAGE = 100
      MAX_REPORTED_INVALID = 5
      # 2 à 40 caractères : lettres, chiffres, espace, apostrophe, tiret ; commence par une lettre ou un chiffre.
      # Aucun métacaractère d'expression régulière ne peut passer (la recherche construit des motifs PostgreSQL).
      INGREDIENT_FORMAT = /\A[\p{L}\p{N}][\p{L}\p{N} '\-]{1,39}\z/

      params do
        optional(:ingredients).maybe(:string)
        optional(:page).filled(:integer, gteq?: 1)
        optional(:count_per_page).filled(:integer, gteq?: 1, lteq?: MAX_COUNT_PER_PAGE)
      end

      rule(:ingredients) do
        next if value.nil?

        terms = ::Recipes::IngredientList.parse(value)
        invalid = terms.grep_v(INGREDIENT_FORMAT)

        if terms.size > MAX_INGREDIENTS
          key.failure("must contain at most #{MAX_INGREDIENTS} ingredients")
        elsif invalid.any?
          key.failure("contains invalid ingredients: #{invalid.first(MAX_REPORTED_INVALID).join(', ')}")
        end
      end
    end
  end
end
```

`app/controllers/v1/recipes_controller.rb` :
```ruby
module V1
  class RecipesController < AppController
    def search
      input = V1::Recipes::SearchContract.validate!(search_params.to_h)

      @recipes, @page, @total_count = ::Recipes::Searcher.new(
        ingredients: ::Recipes::IngredientList.parse(input[:ingredients]),
        page: input[:page],
        count_per_page: input[:count_per_page]
      ).search
    end

    private

    def search_params
      params.permit(:ingredients, :page, :count_per_page)
    end
  end
end
```

- [ ] **Step 5: Vérifier le succès**

Run: `make test`
Expected: `0 failures`.

- [ ] **Step 6: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 5: Recherche en SQL indexé, déterministe, par mot entier (PERF-01, PERF-02, PERF-03)

**Files:**
- Create: `db/migrate/20260913000001_add_trigram_index_to_recipe_ingredients.rb`
- Modify: `app/services/recipes/searcher.rb`, `db/schema.rb` (régénéré)
- Test: `spec/services/recipes/searcher_spec.rb` (réécrit)

**Interfaces:**
- Consumes: `Recipes::Searcher.new(ingredients:, page:, count_per_page:)` appelé par le contrôleur (tâche 4) avec des termes normalisés et validés.
- Produces: `Recipes::Searcher#search → [Array<Recipe>, Integer page, Integer total_count]` (signature inchangée) ; `Recipes::Searcher.pattern_for(ingredient) → String` (motif ARE PostgreSQL) ; `DEFAULT_PAGE = 1`, `DEFAULT_COUNT_PER_PAGE = 100` ; index `index_recipe_ingredients_on_description_trgm`.

- [ ] **Step 1: Réécrire la spec du service**

`spec/services/recipes/searcher_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe Recipes::Searcher do
  def recipe_with(*descriptions, name: "Recipe")
    create(:recipe, name:).tap do |recipe|
      descriptions.each { |description| create(:recipe_ingredient, recipe:, ingredient_description: description) }
    end
  end

  def search(ingredients, page: nil, count_per_page: nil)
    described_class.new(ingredients:, page:, count_per_page:).search
  end

  describe "#search" do
    let!(:rice_and_bread) { recipe_with("1/2 cup of rice", "half bread", "1 cup water") }
    let!(:rice_only) { recipe_with("1/2 cup of rice", "1 cup water") }

    it "classe les recettes par nombre d'ingrédients trouvés" do
      recipes, page, total_count = search([ "bread", "rice" ])

      expect(page).to eq(1)
      expect(total_count).to eq(2)
      expect(recipes).to eq([ rice_and_bread, rice_only ])
    end

    it "ne compte qu'une fois un terme présent dans plusieurs lignes de la même recette" do
      double_rice = recipe_with("1 cup white rice", "1 cup brown rice")

      recipes, = search([ "rice", "bread" ])

      expect(recipes.first).to eq(rice_and_bread)
      expect(recipes).to include(double_rice)
    end

    it "pagine" do
      recipes, page, total_count = search([ "bread", "rice" ], page: 2, count_per_page: 1)

      expect([ recipes, page, total_count ]).to eq([ [ rice_only ], 2, 2 ])
    end

    it "renvoie une page vide au-delà des résultats" do
      recipes, page, total_count = search([ "bread", "rice" ], page: 3, count_per_page: 1)

      expect([ recipes, page, total_count ]).to eq([ [], 3, 2 ])
    end

    it "renvoie un résultat vide sans correspondance" do
      expect(search([ "milk", "sugar" ])).to eq([ [], 1, 0 ])
    end

    it "renvoie un résultat vide sans terme, sans interroger la base" do
      expect(RecipeIngredient).not_to receive(:where)

      expect(search([])).to eq([ [], 1, 0 ])
    end

    it "précharge les ingrédients des recettes renvoyées" do
      recipes, = search([ "rice" ])

      expect(recipes.map { |recipe| recipe.association(:recipe_ingredients).loaded? }.uniq).to eq([ true ])
    end
  end

  describe "ordre à score égal (régression PERF-02)" do
    it "départage par identifiant et parcourt chaque recette exactement une fois" do
      tied = Array.new(5) { |n| recipe_with("#{n + 1} eggs", name: "Tie #{n}") }

      pages = (1..5).flat_map { |page| search([ "egg" ], page:, count_per_page: 1).first }

      expect(pages.map(&:id)).to eq(tied.map(&:id).sort)
      expect(search([ "egg" ], page: 1, count_per_page: 5).first).to eq(search([ "egg" ], page: 1, count_per_page: 5).first)
    end
  end

  describe "correspondance par mot entier (régression PERF-03)" do
    {
      "egg"    => { matches: [ "2 large eggs", "1 egg", "EGG yolk" ], rejects: [ "1 eggplant, cubed" ] },
      "rice"   => { matches: [ "1 cup white rice" ], rejects: [ "2 ounces licorice" ] },
      "ice"    => { matches: [ "1 cup crushed ice" ], rejects: [ "1 cup rice", "juice of 1 lemon" ] },
      "tomato" => { matches: [ "3 tomatoes, diced", "1 tomato" ], rejects: [ "tomatillo salsa" ] },
      "berry"  => { matches: [ "1 cup berries", "1 berry" ], rejects: [ "1 cup blueberries" ] },
      "eggs"   => { matches: [ "1 egg" ], rejects: [] },
      "white rice" => { matches: [ "2 cups white rice" ], rejects: [ "1 cup rice, white or brown" ] }
    }.each do |term, cases|
      it "« #{term} » trouve #{cases[:matches].inspect} et ignore #{cases[:rejects].inspect}" do
        expected = cases[:matches].map { |description| recipe_with(description) }
        cases[:rejects].each { |description| recipe_with(description) }

        recipes, = search([ term ])

        expect(recipes).to match_array(expected)
      end
    end
  end

  describe ".pattern_for" do
    it "échappe les métacaractères en défense en profondeur" do
      expect(described_class.pattern_for("a.b")).to eq('\ma\.b(s|es)?\M')
    end

    it "gère le pluriel en -ies" do
      expect(described_class.pattern_for("berries")).to eq('\mberr(y|ies)\M')
    end
  end
end
```

Note : le `let!` du premier `describe` ne concerne que ce bloc ; les blocs de régression créent leurs propres données, isolées par transaction.

- [ ] **Step 2: Vérifier l'échec**

Run: `make test ARGS="spec/services/recipes/searcher_spec.rb"`
Expected: FAIL — `NoMethodError: undefined method 'pattern_for'`, la correspondance `egg` inclut `eggplant`, et `eggs` ne trouve pas `1 egg`.

- [ ] **Step 3: Écrire la migration**

`db/migrate/20260913000001_add_trigram_index_to_recipe_ingredients.rb` :
```ruby
class AddTrigramIndexToRecipeIngredients < ActiveRecord::Migration[7.2]
  # CREATE INDEX CONCURRENTLY ne peut pas s'exécuter dans une transaction.
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm"

    add_index :recipe_ingredients, :ingredient_description,
      using: :gin,
      opclass: :gin_trgm_ops,
      algorithm: :concurrently,
      name: "index_recipe_ingredients_on_description_trgm"
  end
end
```

```bash
make migrate
grep -n "pg_trgm\|gin_trgm_ops" db/schema.rb
```
Expected: `db/schema.rb` passe à `ActiveRecord::Schema[7.2].define(version: 2026_09_13_000001)` et contient `enable_extension "pg_trgm"` et l'index `gin_trgm_ops`.

- [ ] **Step 4: Réécrire le service**

`app/services/recipes/searcher.rb` :
```ruby
module Recipes
  # Recherche des recettes contenant des ingrédients, entièrement en SQL :
  # filtre indexé (pg_trgm), score, ordre total et pagination côté base.
  class Searcher
    DEFAULT_COUNT_PER_PAGE = 100
    DEFAULT_PAGE = 1

    attr_reader :ingredients, :count_per_page, :page

    # Motif d'expression régulière PostgreSQL (ARE) pour un terme, en mot entier,
    # au singulier ou au pluriel anglais : "egg" → \megg(s|es)?\M, "berry" → \mberr(y|ies)\M.
    def self.pattern_for(ingredient)
      singular = ingredient.singularize

      stem, suffix =
        if singular.end_with?("y")
          [ singular.delete_suffix("y"), "(y|ies)" ]
        else
          [ singular, "(s|es)?" ]
        end

      "\\m#{Regexp.escape(stem)}#{suffix}\\M"
    end

    # ingredients    - Array de String normalisés (voir Recipes::IngredientList).
    # count_per_page - Integer, taille de page (défaut 100).
    # page           - Integer, à partir de 1 (défaut 1).
    def initialize(ingredients:, count_per_page: nil, page: nil)
      @ingredients = ingredients
      @count_per_page = count_per_page || DEFAULT_COUNT_PER_PAGE
      @page = page || DEFAULT_PAGE
    end

    # Renvoie [ recettes de la page, page, nombre total de recettes trouvées ].
    def search
      return [ [], page, 0 ] if ingredients.empty?

      [ recipes_for_page, page, total_count ]
    end

    private

    def recipes_for_page
      ids = matching_ingredients
        .group(:recipe_id)
        .select(:recipe_id, "#{score_sql} AS score")
        .order(Arel.sql("score DESC"), :recipe_id)
        .limit(count_per_page)
        .offset((page - 1) * count_per_page)
        .map(&:recipe_id)

      recipes_by_id = Recipe.includes(:recipe_ingredients).where(id: ids).index_by(&:id)
      ids.map { |id| recipes_by_id.fetch(id) }
    end

    def total_count
      matching_ingredients.distinct.count(:recipe_id)
    end

    def matching_ingredients
      condition = Array.new(patterns.size, "recipe_ingredients.ingredient_description ~* ?").join(" OR ")
      RecipeIngredient.where(condition, *patterns)
    end

    # Une recette gagne un point par terme trouvé, quel que soit le nombre de lignes qui le contiennent.
    def score_sql
      patterns.map do |pattern|
        RecipeIngredient.sanitize_sql_array([ "bool_or(recipe_ingredients.ingredient_description ~* ?)::int", pattern ])
      end.join(" + ")
    end

    def patterns
      @patterns ||= ingredients.map { |ingredient| self.class.pattern_for(ingredient) }
    end
  end
end
```

- [ ] **Step 5: Vérifier le succès**

Run: `make test`
Expected: `0 failures`. Si un cas du tableau PERF-03 échoue, corriger `pattern_for` et non le cas : ils décrivent le comportement spécifié en 2.5.

- [ ] **Step 6: Vérifier que l'index est utilisé sur les données réelles**

```bash
docker compose run --rm tools bin/rails runner '
  searcher = Recipes::Searcher.new(ingredients: %w[ rice bread ])
  sql = searcher.send(:matching_ingredients).to_sql
  puts ActiveRecord::Base.connection.execute("EXPLAIN ANALYZE #{sql}").values.flatten
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  recipes, page, total = Recipes::Searcher.new(ingredients: %w[ rice bread ], count_per_page: 20).search
  puts "page=#{page} total=#{total} recettes=#{recipes.size} en #{((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round} ms"
'
```
Expected: le plan contient `Bitmap Index Scan on index_recipe_ingredients_on_description_trgm` ; `recettes=20` et `total` supérieur à 20. Relever le temps pour le rapport final.

- [ ] **Step 7: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 6: Modèles validés et amorçage fiable (MOD-01, MOD-02, QA-02)

**Files:**
- Move: `config/data/recipes-en.json` → `db/data/recipes-en.json`
- Modify: `app/models/recipe.rb`, `app/models/recipe_ingredient.rb`, `app/services/recipes/populator.rb`, `db/seeds.rb`, `spec/factories/recipe.rb`, `spec/factories/recipe_ingredient.rb`, `Gemfile`, `Gemfile.lock`
- Create: `spec/fixtures/files/recipes-sample.json`
- Test: `spec/models/recipe_spec.rb`, `spec/models/recipe_ingredient_spec.rb`, `spec/services/recipes/populator_spec.rb`

**Interfaces:**
- Consumes: schéma de la tâche 5.
- Produces: `Recipes::Populator.new(path: DATA_PATH, batch_size: BATCH_SIZE)` avec `DATA_PATH = Rails.root.join("db/data/recipes-en.json")`, `BATCH_SIZE = 1_000` ; `#populate → Integer` (recettes insérées, `0` si la table contient déjà des recettes). Factories `:recipe` et `:recipe_ingredient` sans Faker.

- [ ] **Step 1: Écrire les specs**

`spec/models/recipe_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe Recipe do
  it "est valide avec la factory" do
    expect(build(:recipe)).to be_valid
  end

  it "exige un nom et une image" do
    recipe = build(:recipe, name: "", result_image_url: nil)

    expect(recipe).not_to be_valid
    expect(recipe.errors.attribute_names).to contain_exactly(:name, :result_image_url)
  end

  it "accepte une catégorie vide (65 recettes du jeu de données) mais pas nil" do
    expect(build(:recipe, category: "")).to be_valid
    expect(build(:recipe, category: nil)).not_to be_valid
  end

  it "refuse une durée négative ou non entière" do
    expect(build(:recipe, duration_in_mins: -1)).not_to be_valid
    expect(build(:recipe, duration_in_mins: "1.5")).not_to be_valid
  end

  it "supprime ses ingrédients avec elle (régression MOD-01)" do
    recipe = create(:recipe_ingredient).recipe

    expect { recipe.destroy! }.to change(RecipeIngredient, :count).by(-1)
  end
end
```

`spec/models/recipe_ingredient_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe RecipeIngredient do
  it "est valide avec la factory" do
    expect(build(:recipe_ingredient)).to be_valid
  end

  it "exige une recette et une description" do
    ingredient = build(:recipe_ingredient, recipe: nil, ingredient_description: " ")

    expect(ingredient).not_to be_valid
    expect(ingredient.errors.attribute_names).to contain_exactly(:recipe, :ingredient_description)
  end
end
```

`spec/fixtures/files/recipes-sample.json` :
```json
[
  {
    "title": "Golden Sweet Cornbread",
    "cook_time": 25,
    "prep_time": 10,
    "ingredients": [ "1 cup all-purpose flour", "1 cup yellow cornmeal" ],
    "category": "Cornbread",
    "image": "https://images.example.com/cornbread.jpg"
  },
  {
    "title": "Monkey Bread I",
    "cook_time": 35,
    "prep_time": 15,
    "ingredients": [ "3 packages refrigerated biscuit dough" ],
    "category": "",
    "image": "https://images.example.com/monkey-bread.jpg"
  },
  {
    "title": "Overnight Oats",
    "prep_time": 5,
    "ingredients": [],
    "category": "Breakfast",
    "image": "https://images.example.com/oats.jpg"
  }
]
```

`spec/services/recipes/populator_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe Recipes::Populator do
  let(:path) { Rails.root.join("spec/fixtures/files/recipes-sample.json") }

  it "insère recettes et ingrédients par lots" do
    inserted = described_class.new(path:, batch_size: 2).populate

    expect(inserted).to eq(3)
    expect(Recipe.count).to eq(3)
    expect(RecipeIngredient.count).to eq(3)
  end

  it "additionne les durées, tolère une durée absente et conserve une catégorie vide" do
    described_class.new(path:).populate

    expect(Recipe.order(:name).pluck(:name, :duration_in_mins, :category)).to eq([
      [ "Golden Sweet Cornbread", 35, "Cornbread" ],
      [ "Monkey Bread I", 50, "" ],
      [ "Overnight Oats", 5, "Breakfast" ]
    ])
  end

  it "est idempotent (régression MOD-02)" do
    described_class.new(path:).populate

    expect { expect(described_class.new(path:).populate).to eq(0) }.not_to change(Recipe, :count)
  end

  it "lit le jeu de données depuis Rails.root, indépendamment du répertoire courant" do
    expect(described_class::DATA_PATH).to eq(Rails.root.join("db/data/recipes-en.json"))
    expect(File).to exist(described_class::DATA_PATH)
  end
end
```

- [ ] **Step 2: Réécrire les factories sans Faker**

`spec/factories/recipe.rb` :
```ruby
FactoryBot.define do
  factory :recipe do
    sequence(:name) { |n| "Recipe #{n}" }
    category { "Main Dishes" }
    sequence(:result_image_url) { |n| "https://images.example.com/recipes/#{n}.jpg" }
    duration_in_mins { 30 }
  end
end
```

`spec/factories/recipe_ingredient.rb` :
```ruby
FactoryBot.define do
  factory :recipe_ingredient do
    recipe
    ingredient_description { "1 cup water" }
  end
end
```

- [ ] **Step 3: Déplacer le jeu de données et vérifier l'échec**

```bash
mkdir -p db/data && git mv config/data/recipes-en.json db/data/recipes-en.json
make test ARGS="spec/models spec/services/recipes/populator_spec.rb"
```
Expected: FAIL — validations absentes, `ArgumentError: unknown keyword: :path`, `uninitialized constant Recipes::Populator::DATA_PATH`.

- [ ] **Step 4: Implémenter**

`app/models/recipe.rb` :
```ruby
class Recipe < ApplicationRecord
  has_many :recipe_ingredients, dependent: :delete_all, inverse_of: :recipe

  validates :name, :result_image_url, presence: true
  validates :category, exclusion: { in: [ nil ], message: "can't be nil" }
  validates :duration_in_mins, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

`app/models/recipe_ingredient.rb` :
```ruby
class RecipeIngredient < ApplicationRecord
  belongs_to :recipe, inverse_of: :recipe_ingredients

  validates :ingredient_description, presence: true
end
```

`app/services/recipes/populator.rb` :
```ruby
module Recipes
  # Charge le jeu de données allrecipes.com. Ne fait rien si des recettes existent déjà.
  class Populator
    DATA_PATH = Rails.root.join("db/data/recipes-en.json")
    BATCH_SIZE = 1_000

    def initialize(path: DATA_PATH, batch_size: BATCH_SIZE)
      @path = path
      @batch_size = batch_size
    end

    # Renvoie le nombre de recettes insérées (0 si la table était déjà remplie).
    def populate
      return 0 if Recipe.exists?

      raw_data.each_slice(@batch_size).sum { |slice| insert(slice) }
    end

    private

    def raw_data
      JSON.parse(File.read(@path))
    end

    def insert(slice)
      recipes = []
      ingredients = []

      slice.each do |data|
        recipe_id = SecureRandom.uuid

        recipes << {
          id: recipe_id,
          name: data.fetch("title"),
          category: data["category"].to_s,
          result_image_url: data.fetch("image"),
          duration_in_mins: data["cook_time"].to_i + data["prep_time"].to_i
        }

        Array(data["ingredients"]).each do |description|
          ingredients << { recipe_id:, ingredient_description: description }
        end
      end

      ActiveRecord::Base.transaction do
        Recipe.insert_all!(recipes)
        RecipeIngredient.insert_all!(ingredients) if ingredients.any?
      end

      recipes.size
    end
  end
end
```

`db/seeds.rb` :
```ruby
inserted = Recipes::Populator.new.populate
puts(inserted.zero? ? "Recettes déjà chargées : rien à faire." : "#{inserted} recettes chargées.")
```

Dans `Gemfile`, supprimer la ligne `gem "faker", "~> 3.8"`, puis :
```bash
docker compose run --rm tools bundle lock
make build
```

- [ ] **Step 5: Vérifier le succès**

Run: `make test`
Expected: `0 failures`.

- [ ] **Step 6: Rejouer l'amorçage réel**

```bash
make reset
docker compose run --rm tools bin/rails runner 'puts [Recipe.count, RecipeIngredient.count].inspect'
make seed
```
Expected: `[10013, 96417]`, puis `Recettes déjà chargées : rien à faire.`

- [ ] **Step 7: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 7: Clé d'API optionnelle, limitation de débit, CORS fermé par défaut (SEC-01)

**Files:**
- Create: `app/controllers/concerns/authorizable.rb`, `app/errors/api_errors/unauthorized_error.rb`, `app/errors/api_errors/too_many_requests_error.rb`, `spec/support/rate_limit.rb`
- Modify: `config/application.rb`, `app/controllers/v1/app_controller.rb`, `config/initializers/cors.rb`, `spec/errors/api_errors/api_error_spec.rb`
- Test: `spec/requests/v1/security_spec.rb`

**Interfaces:**
- Consumes: `ApiErrors::ApiError` (tâche 2), `assert_response_schema_confirm` et les réponses `Unauthorized` / `RateLimited` de l'OpenAPI (tâche 3).
- Produces: `Rails.configuration.x.api_key` (`String | nil`), `Rails.configuration.x.rate_limit_per_minute` (`Integer`), `Rails.configuration.x.rate_limit_store` (`ActiveSupport::Cache::MemoryStore`) ; concern `Authorizable` (`HEADER = "X-Api-Key"`) ; `ApiErrors::UnauthorizedError.new` (401, `unauthorized`) ; `ApiErrors::TooManyRequestsError.new` (429, `rate_limited`). Tout contrôleur héritant de `V1::AppController` est limité puis authentifié, dans cet ordre.

- [ ] **Step 1: Écrire les specs**

`spec/support/rate_limit.rb` :
```ruby
# Le compteur de débit est partagé par le processus : chaque spec de requête repart de zéro.
RSpec.configure do |config|
  config.before(type: :request) { Rails.configuration.x.rate_limit_store.clear }
end
```

`spec/requests/v1/security_spec.rb` :
```ruby
require "rails_helper"

RSpec.describe "Sécurité de /v1", type: :request do
  let(:url) { "/v1/recipes/search" }
  let(:body) { JSON.parse(response.body) }

  describe "clé d'API" do
    it "laisse passer les requêtes sans clé quand API_KEY n'est pas défini" do
      get url

      expect(response).to have_http_status(200)
    end

    context "quand API_KEY est défini" do
      around do |example|
        Rails.configuration.x.api_key = "s3cr3t-key"
        example.run
      ensure
        Rails.configuration.x.api_key = nil
      end

      it "refuse une requête sans clé" do
        get url

        expect(response).to have_http_status(401)
        assert_response_schema_confirm(401)
        expect(body.dig("error", "id")).to eq("unauthorized")
      end

      it "refuse une clé invalide" do
        get url, headers: { "X-Api-Key" => "wrong" }

        expect(response).to have_http_status(401)
      end

      it "accepte la bonne clé" do
        get url, headers: { "X-Api-Key" => "s3cr3t-key" }

        expect(response).to have_http_status(200)
      end
    end
  end

  describe "limitation de débit" do
    it "renvoie 429 au-delà de la limite par minute, clé valide ou non" do
      limit = Rails.configuration.x.rate_limit_per_minute
      limit.times { get url }
      expect(response).to have_http_status(200)

      get url

      expect(response).to have_http_status(429)
      assert_response_schema_confirm(429)
      expect(body.dig("error", "id")).to eq("rate_limited")
    end
  end

  describe "CORS" do
    it "n'autorise aucune origine tierce par défaut (régression SEC-01)" do
      get url, headers: { "Origin" => "https://evil.example" }

      expect(response.headers.to_h.keys.map(&:downcase)).not_to include("access-control-allow-origin")
    end
  end
end
```

Dans `spec/errors/api_errors/api_error_spec.rb`, étendre le premier exemple :
```ruby
    errors = [
      ApiErrors::GenericError.new,
      ApiErrors::ResourceNotFoundError.new("Couldn't find Recipe"),
      ApiErrors::ValidationError.new(page: [ "must be greater than or equal to 1" ]),
      ApiErrors::UnauthorizedError.new,
      ApiErrors::TooManyRequestsError.new
    ]

    expect(errors.map { |error| error.as_json.keys }.uniq).to eq([ %i[ http_code id developer_message details ] ])
    expect(errors.map(&:http_code)).to eq([ 500, 404, 422, 401, 429 ])
    expect(errors.map(&:id)).to eq(%w[ generic resource_not_found validation_failed unauthorized rate_limited ])
```

- [ ] **Step 2: Vérifier l'échec**

Run: `make test ARGS="spec/requests/v1/security_spec.rb spec/errors"`
Expected: FAIL — `NoMethodError` sur `rate_limit_store` (nil), aucun 401 ni 429.

- [ ] **Step 3: Implémenter**

Dans `config/application.rb`, après `config.api_only = true` :
```ruby

    # Clé d'API optionnelle : si elle est vide, l'API est publique.
    config.x.api_key = ENV["API_KEY"].presence
    # Requêtes par minute et par IP sur /v1. Compteur en mémoire, propre à chaque processus Puma.
    config.x.rate_limit_per_minute = Integer(ENV.fetch("RATE_LIMIT_PER_MINUTE", 60))
    config.x.rate_limit_store = ActiveSupport::Cache::MemoryStore.new
```

`app/errors/api_errors/unauthorized_error.rb` :
```ruby
module ApiErrors
  class UnauthorizedError < ApiError
    def initialize
      super(
        http_code: 401,
        id: "unauthorized",
        developer_message: "A valid X-Api-Key header is required",
        details: {}
      )
    end
  end
end
```

`app/errors/api_errors/too_many_requests_error.rb` :
```ruby
module ApiErrors
  class TooManyRequestsError < ApiError
    def initialize
      super(
        http_code: 429,
        id: "rate_limited",
        developer_message: "Too many requests, retry in a minute",
        details: {}
      )
    end
  end
end
```

`app/controllers/concerns/authorizable.rb` :
```ruby
# Exige l'en-tête X-Api-Key uniquement si API_KEY est défini côté serveur.
module Authorizable
  extend ActiveSupport::Concern

  HEADER = "X-Api-Key"

  included do
    before_action :authorize_api_key!
  end

  private

  def authorize_api_key!
    expected = Rails.configuration.x.api_key
    return if expected.blank?
    # Comparaison en temps constant : la durée ne révèle pas le préfixe correct.
    return if ActiveSupport::SecurityUtils.secure_compare(request.headers[HEADER].to_s, expected)

    raise ApiErrors::UnauthorizedError
  end
end
```

`app/controllers/v1/app_controller.rb` :
```ruby
module V1
  class AppController < ApplicationController
    # Déclarée avant Authorizable : les tentatives de clé sont elles aussi comptées.
    rate_limit to: Rails.configuration.x.rate_limit_per_minute,
      within: 1.minute,
      store: Rails.configuration.x.rate_limit_store,
      with: -> { raise ApiErrors::TooManyRequestsError }

    include Authorizable
  end
end
```

`config/initializers/cors.rb` :
```ruby
# CORS désactivé par défaut : le front est servi par la même origine que l'API.
# CORS_ORIGINS="https://app.example.com,https://admin.example.com" l'ouvre à des clients tiers, en lecture seule.
cors_origins = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).compact_blank

if cors_origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*cors_origins)
      resource "/v1/*", headers: :any, methods: %i[ get options head ]
    end
  end
end
```

- [ ] **Step 4: Vérifier le succès**

Run: `make test`
Expected: `0 failures`.

- [ ] **Step 5: Vérifier CORS activé à la main**

```bash
docker compose run --rm -e CORS_ORIGINS=https://app.example.com tools bin/rails runner '
  app = Rails.application
  env = Rack::MockRequest.env_for("/v1/recipes/search", "HTTP_ORIGIN" => "https://app.example.com", "HTTP_HOST" => "localhost")
  status, headers, = app.call(env)
  puts [ status, headers["access-control-allow-origin"] ].inspect
'
```
Expected: `[200, "https://app.example.com"]`.

- [ ] **Step 6: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 8: Migration du front de Create React App vers Vite (WEB-03, WEB-04 partiel, QA-01 partiel)

Migration **mécanique** : le comportement de l'interface ne change pas ici, il est corrigé à la tâche 9. Seuls changent l'outillage, le montage React 18 (`createRoot`) et l'URL d'API, qui n'est plus codée en dur.

**Files:**
- Delete: `web/public/index.html`, `web/public/manifest.json`, `web/public/logo192.png`, `web/public/logo512.png`, `web/src/logo.svg`, `web/src/reportWebVitals.js`, `web/src/setupTests.js`, `web/src/App.test.js`, `web/src/index.js`, `web/README.md`, `web/jsconfig.json`, `web/.gitignore`, `web/package-lock.json`
- Move: `web/src/App.js` → `web/src/App.jsx`
- Create: `web/index.html`, `web/vite.config.js`, `web/eslint.config.js`, `web/.env.example`, `web/src/main.jsx`, `web/src/test/setup.js`, `web/src/App.test.jsx`
- Modify: `web/package.json`, `web/src/App.jsx` (URL d'API, import React), `Makefile`, `.gitignore`

**Interfaces:**
- Consumes: API sur `http://localhost:3000` (tâche 1).
- Produces: scripts npm `dev`, `build`, `preview`, `test`, `test:watch`, `lint` ; build dans `web/dist/` ; variables `VITE_API_URL`, `VITE_API_KEY`, `API_PROXY_TARGET` ; proxy de développement `/v1` ; environnement de test Vitest + jsdom + jest-dom (globals activés) ; cibles `make web-install|web-dev|web-test|web-lint|web-build`.

- [ ] **Step 1: Retirer Create React App**

```bash
git rm -q web/public/index.html web/public/manifest.json web/public/logo192.png web/public/logo512.png \
  web/src/logo.svg web/src/reportWebVitals.js web/src/setupTests.js web/src/App.test.js web/src/index.js \
  web/README.md web/jsconfig.json web/.gitignore web/package-lock.json
git mv web/src/App.js web/src/App.jsx
rm -rf web/node_modules
```

- [ ] **Step 2: Écrire la configuration Vite**

`web/package.json` :
```json
{
  "name": "futa-recipes-web",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "engines": {
    "node": ">=18.18"
  },
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint ."
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-paginate": "^8.3.0"
  },
  "devDependencies": {
    "@eslint/js": "^9.39.5",
    "@testing-library/dom": "^10.4.1",
    "@testing-library/jest-dom": "^6.8.0",
    "@testing-library/react": "^16.3.3",
    "@testing-library/user-event": "^14.6.7",
    "@vitejs/plugin-react": "^4.7.0",
    "eslint": "^9.39.5",
    "eslint-plugin-react-hooks": "^5.2.0",
    "eslint-plugin-react-refresh": "^0.4.26",
    "globals": "^16.5.0",
    "jsdom": "^26.1.0",
    "vite": "^6.4.3",
    "vitest": "^3.2.7"
  }
}
```

`web/vite.config.js` :
```js
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [ react() ],
    server: {
      port: 5173,
      // /v1 est relayé vers l'API : front et API partagent l'origine, comme en production.
      proxy: {
        "/v1": { target: env.API_PROXY_TARGET || "http://localhost:3000", changeOrigin: true },
      },
    },
    test: {
      environment: "jsdom",
      globals: true,
      setupFiles: "./src/test/setup.js",
      css: false,
    },
  };
});
```

`web/eslint.config.js` :
```js
import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default [
  { ignores: [ "dist" ] },
  {
    files: [ "**/*.{js,jsx}" ],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    plugins: { "react-hooks": reactHooks, "react-refresh": reactRefresh },
    rules: {
      ...js.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      // ESLint seul ne voit pas l'usage d'un composant en JSX.
      "no-unused-vars": [ "error", { varsIgnorePattern: "^[A-Z_]" } ],
      "react-refresh/only-export-components": [ "warn", { allowConstantExport: true } ],
    },
  },
  {
    files: [ "**/*.test.{js,jsx}", "src/test/**" ],
    languageOptions: { globals: { ...globals.node, ...globals.vitest } },
  },
  {
    files: [ "vite.config.js", "eslint.config.js" ],
    languageOptions: { globals: globals.node },
  },
];
```

`web/index.html` :
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" href="/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Find recipes you can cook with the ingredients you already have." />
    <title>Futa Recipes</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

`web/.env.example` :
```
# Vide : le front appelle l'API sur sa propre origine (proxy Vite en dev, même image en production).
VITE_API_URL=
# Déploiement privé uniquement : cette valeur est lisible par quiconque charge le front.
VITE_API_KEY=
# Cible du proxy /v1 du serveur de développement.
API_PROXY_TARGET=http://localhost:3000
```

`web/src/main.jsx` :
```jsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.jsx";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
```

`web/src/test/setup.js` :
```js
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 3: Adapter App.jsx au strict nécessaire**

Dans `web/src/App.jsx` :
- remplacer `import React, { useState } from 'react';` par `import { useState } from 'react';`
- remplacer `const BASE_API_URL = "https://pennylane-recipes-new-api.herokuapp.com"` par :
```jsx
const BASE_API_URL = import.meta.env.VITE_API_URL ?? "";
```

- [ ] **Step 4: Écrire le test de fumée (remplace le test CRA en échec)**

`web/src/App.test.jsx` :
```jsx
import { render, screen } from "@testing-library/react";
import App from "./App.jsx";

test("affiche le formulaire de saisie des ingrédients", () => {
  render(<App />);

  expect(screen.getByRole("heading", { name: /what ingredients do you have/i })).toBeInTheDocument();
});
```

- [ ] **Step 5: Installer, tester, construire**

```bash
cd web && npm install && npm run lint && npm test && npm run build && ls dist && cd ..
```
Expected: `package-lock.json` créé ; lint sans erreur ; `1 passed` ; `dist/` contient `index.html` et `assets/`.

- [ ] **Step 6: Ajouter les cibles front au Makefile et ignorer web/.env**

Dans `Makefile`, ajouter `web-install web-dev web-test web-lint web-build` à `.PHONY` et :
```make
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
```

Dans `.gitignore`, sous `/web/dist/`, ajouter `/web/.env`.

- [ ] **Step 7: Vérifier le proxy de développement**

```bash
docker compose up -d api
until curl -fsS http://localhost:3000/up >/dev/null; do sleep 2; done
(cd web && npx vite --port 5173 --strictPort > /tmp/futa-vite.log 2>&1 &)
until curl -fsS http://localhost:5173/ >/dev/null; do sleep 1; done
curl -s "http://localhost:5173/v1/recipes/search?ingredients=rice&count_per_page=1" | head -c 200; echo
pkill -f "vite --port 5173"; docker compose down
```
Expected: JSON de l'API renvoyé via le port 5173.

- [ ] **Step 8: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 9: Interface de recherche corrigée, accessible et testée (WEB-01, WEB-02, WEB-03, WEB-04, ID-01)

**Files:**
- Create: `web/src/api/recipes.js`, `web/src/lib/ingredients.js`, `web/src/components/IngredientForm.jsx`, `web/src/components/IngredientList.jsx`, `web/src/components/RecipeCard.jsx`, `web/src/components/SearchResults.jsx`
- Modify: `web/src/App.jsx` (réécrit), `web/src/App.css` (réécrit), `web/src/index.css` (réécrit), `web/src/App.test.jsx` (réécrit)
- Test: `web/src/api/recipes.test.js`, `web/src/lib/ingredients.test.js`, `web/src/App.test.jsx`

**Interfaces:**
- Consumes: contrat HTTP de 2.4 ; variables `VITE_API_URL` et `VITE_API_KEY` (tâche 8).
- Produces:
  - `searchRecipes({ ingredients: string[], page: number, perPage = PER_PAGE, signal }) → Promise<{ recipes, page, totalCount }>` ; lève `ApiError` (`message` destiné à l'utilisateur, `status` HTTP ou `0` pour le réseau) ou laisse passer `AbortError` ; `PER_PAGE = 20`.
  - `addIngredients(list, raw) → string[]` (découpe sur `,`, normalise, déduplique, plafonne à `MAX_INGREDIENTS = 20`, renvoie **la même référence** si rien n'est ajouté) ; `removeIngredient(list, term) → string[]`.
  - Composants : `IngredientForm({ value, onChange, onSubmit, atLimit })`, `IngredientList({ ingredients, onRemove })`, `RecipeCard({ recipe })`, `SearchResults({ status, error, result, onPageChange(page), onRetry() })` avec `status` ∈ `idle | loading | success | error`.

- [ ] **Step 1: Écrire les tests unitaires**

`web/src/lib/ingredients.test.js` :
```js
import { addIngredients, MAX_INGREDIENTS, removeIngredient } from "./ingredients.js";

describe("addIngredients", () => {
  test("normalise espaces et casse", () => {
    expect(addIngredients([], "  White   RICE ")).toEqual([ "white rice" ]);
  });

  test("découpe une saisie contenant des virgules et déduplique", () => {
    expect(addIngredients([ "rice" ], "bread, RICE,,eggs")).toEqual([ "rice", "bread", "eggs" ]);
  });

  test("renvoie la même liste quand rien n'est ajouté", () => {
    const list = [ "rice" ];

    expect(addIngredients(list, " , ")).toBe(list);
  });

  test(`plafonne à ${MAX_INGREDIENTS} ingrédients, comme l'API`, () => {
    const full = Array.from({ length: MAX_INGREDIENTS }, (_, index) => `item ${index}`);

    expect(addIngredients(full, "rice")).toBe(full);
  });
});

test("removeIngredient retire un terme", () => {
  expect(removeIngredient([ "rice", "bread" ], "rice")).toEqual([ "bread" ]);
});
```

`web/src/api/recipes.test.js` :
```js
import { ApiError, searchRecipes } from "./recipes.js";

const okResponse = (body) => ({ ok: true, status: 200, json: async () => body });

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
  vi.resetModules();
});

test("encode les paramètres et convertit la réponse (régression WEB-03)", async () => {
  const fetchMock = vi.fn().mockResolvedValue(okResponse({ recipes: [], page: 2, total_count: 41 }));
  vi.stubGlobal("fetch", fetchMock);

  const result = await searchRecipes({ ingredients: [ "crème fraîche", "salt & pepper" ], page: 2 });

  const [ url, options ] = fetchMock.mock.calls[0];
  expect(url).toBe("/v1/recipes/search?ingredients=cr%C3%A8me+fra%C3%AEche%2Csalt+%26+pepper&page=2&count_per_page=20");
  expect(options.headers).toEqual({ Accept: "application/json" });
  expect(result).toEqual({ recipes: [], page: 2, totalCount: 41 });
});

test("envoie X-Api-Key quand VITE_API_KEY est défini", async () => {
  vi.stubEnv("VITE_API_KEY", "k-123");
  vi.resetModules();
  const { searchRecipes: search } = await import("./recipes.js");
  const fetchMock = vi.fn().mockResolvedValue(okResponse({ recipes: [], page: 1, total_count: 0 }));
  vi.stubGlobal("fetch", fetchMock);

  await search({ ingredients: [ "rice" ], page: 1 });

  expect(fetchMock.mock.calls[0][1].headers).toEqual({ Accept: "application/json", "X-Api-Key": "k-123" });
});

test.each([
  [ 401, /requires an api key/i ],
  [ 422, /isn't valid/i ],
  [ 429, /too many searches/i ],
  [ 503, /error \(503\)/i ],
])("traduit le statut %i en message utilisateur", async (status, message) => {
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status, json: async () => ({}) }));

  const error = await searchRecipes({ ingredients: [ "rice" ], page: 1 }).catch((caught) => caught);

  expect(error).toBeInstanceOf(ApiError);
  expect(error.status).toBe(status);
  expect(error.message).toMatch(message);
});

test("signale une panne réseau", async () => {
  vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));

  await expect(searchRecipes({ ingredients: [ "rice" ], page: 1 })).rejects.toThrow(/can't reach the server/i);
});

test("laisse passer une annulation", async () => {
  vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new DOMException("Aborted", "AbortError")));

  await expect(searchRecipes({ ingredients: [ "rice" ], page: 1 })).rejects.toHaveProperty("name", "AbortError");
});
```

- [ ] **Step 2: Écrire les tests d'interface**

`web/src/App.test.jsx` :
```jsx
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import App from "./App.jsx";

const recipe = (n) => ({
  id: `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
  name: `Recipe ${n}`,
  duration_in_mins: 30,
  category: "Dinner",
  result_image_url: `https://images.example.com/${n}.jpg`,
  ingredients: [ "1 cup rice" ],
});
const ok = (body) => ({ ok: true, status: 200, json: async () => body });
const failure = (status) => ({ ok: false, status, json: async () => ({}) });

function mockFetch(...responses) {
  const fetchMock = vi.fn();
  responses.forEach((response) => fetchMock.mockResolvedValueOnce(response));
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

const paramsOf = (fetchMock, call = 0) => new URL(fetchMock.mock.calls[call][0], "http://localhost").searchParams;
const input = () => screen.getByLabelText(/add an ingredient/i);
const findButton = () => screen.getByRole("button", { name: /find recipes/i });

afterEach(() => vi.unstubAllGlobals());

test("affiche le formulaire de saisie des ingrédients", () => {
  render(<App />);

  expect(screen.getByRole("heading", { name: /what ingredients do you have/i })).toBeInTheDocument();
  expect(findButton()).toBeDisabled();
});

test("recherche avec les ingrédients saisis et affiche le nombre de résultats", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(ok({ recipes: [ recipe(1), recipe(2) ], page: 1, total_count: 2 }));
  render(<App />);

  await user.type(input(), "Rice{Enter}");
  await user.type(input(), "bread{Enter}");
  await user.click(findButton());

  expect(await screen.findByRole("heading", { name: "2 recipes found" })).toBeInTheDocument();
  expect(screen.getAllByRole("article")).toHaveLength(2);
  expect(paramsOf(fetchMock).get("ingredients")).toBe("rice,bread");
  expect(paramsOf(fetchMock).get("page")).toBe("1");
  expect(paramsOf(fetchMock).get("count_per_page")).toBe("20");
});

test("demande la page cliquée et dérive le nombre de pages de total_count (régressions WEB-01, WEB-02)", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(
    ok({ recipes: [ recipe(1) ], page: 1, total_count: 45 }),
    ok({ recipes: [ recipe(21) ], page: 2, total_count: 45 }),
  );
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.click(findButton());
  await screen.findByRole("heading", { name: "45 recipes found" });

  expect(screen.getByRole("button", { name: "Page 3" })).toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Page 4" })).not.toBeInTheDocument();

  await user.click(screen.getByRole("button", { name: "Page 2" }));

  expect(await screen.findByText("Recipe 21")).toBeInTheDocument();
  expect(paramsOf(fetchMock, 1).get("page")).toBe("2");
  expect(paramsOf(fetchMock, 1).get("ingredients")).toBe("rice");
});

test("pagine sur la recherche lancée, même si la liste a changé depuis", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(
    ok({ recipes: [ recipe(1) ], page: 1, total_count: 45 }),
    ok({ recipes: [ recipe(21) ], page: 2, total_count: 45 }),
  );
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.click(findButton());
  await screen.findByRole("heading", { name: "45 recipes found" });
  await user.type(input(), "bread{Enter}");
  await user.click(screen.getByRole("button", { name: "Page 2" }));

  await screen.findByText("Recipe 21");
  expect(paramsOf(fetchMock, 1).get("ingredients")).toBe("rice");
});

test("inclut l'ingrédient tapé mais pas encore ajouté", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(ok({ recipes: [], page: 1, total_count: 0 }));
  render(<App />);

  await user.type(input(), "eggs");
  await user.click(findButton());

  expect(await screen.findByText(/no recipe uses these ingredients/i)).toBeInTheDocument();
  expect(paramsOf(fetchMock).get("ingredients")).toBe("eggs");
  expect(input()).toHaveValue("");
});

test("affiche une erreur compréhensible et permet de réessayer", async () => {
  const user = userEvent.setup();
  const fetchMock = mockFetch(failure(429), ok({ recipes: [ recipe(1) ], page: 1, total_count: 1 }));
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.click(findButton());

  expect(await screen.findByRole("alert")).toHaveTextContent(/too many searches/i);

  await user.click(screen.getByRole("button", { name: /try again/i }));

  expect(await screen.findByRole("heading", { name: "1 recipe found" })).toBeInTheDocument();
  expect(fetchMock).toHaveBeenCalledTimes(2);
});

test("ignore doublons et saisies vides ; Reset vide la liste et le champ (régression WEB-04)", async () => {
  const user = userEvent.setup();
  render(<App />);

  await user.type(input(), "rice{Enter}");
  await user.type(input(), " RICE {Enter}");
  const list = screen.getByRole("list", { name: /your ingredients/i });
  expect(within(list).getAllByRole("listitem")).toHaveLength(1);

  await user.click(screen.getByRole("button", { name: "Remove rice" }));
  expect(screen.queryByRole("list", { name: /your ingredients/i })).not.toBeInTheDocument();

  await user.type(input(), "bread{Enter}");
  await user.type(input(), "salt");
  await user.click(screen.getByRole("button", { name: /reset/i }));

  expect(input()).toHaveValue("");
  expect(screen.queryByRole("list", { name: /your ingredients/i })).not.toBeInTheDocument();
});
```

- [ ] **Step 3: Vérifier l'échec**

Run: `cd web && npm test; cd ..`
Expected: FAIL — modules `./ingredients.js` et `./recipes.js` introuvables ; tests d'interface en échec (libellé « Add an ingredient » absent).

- [ ] **Step 4: Implémenter la logique**

`web/src/lib/ingredients.js` :
```js
export const MAX_INGREDIENTS = 20;

const normalize = (term) => term.trim().replace(/\s+/g, " ").toLowerCase();

// Ajoute une saisie (éventuellement "rice, eggs") : termes normalisés, sans vide ni doublon,
// dans la limite acceptée par l'API. Renvoie la même liste si rien n'est ajouté.
export function addIngredients(list, raw) {
  return raw.split(",").map(normalize).reduce((accumulator, term) => {
    if (term === "" || accumulator.includes(term) || accumulator.length >= MAX_INGREDIENTS) return accumulator;
    return [ ...accumulator, term ];
  }, list);
}

export function removeIngredient(list, term) {
  return list.filter((item) => item !== term);
}
```

`web/src/api/recipes.js` :
```js
export const PER_PAGE = 20;

const API_URL = (import.meta.env.VITE_API_URL ?? "").replace(/\/+$/, "");
const API_KEY = import.meta.env.VITE_API_KEY;

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

const MESSAGES = {
  401: "This server requires an API key. Ask its administrator to rebuild the site with one.",
  422: "One of your ingredients isn't valid. Use 2 to 40 letters, numbers, spaces, hyphens or apostrophes.",
  429: "Too many searches in a short time. Wait a minute, then try again.",
};

export async function searchRecipes({ ingredients, page, perPage = PER_PAGE, signal }) {
  const params = new URLSearchParams({
    ingredients: ingredients.join(","),
    page: String(page),
    count_per_page: String(perPage),
  });
  const headers = { Accept: "application/json" };
  if (API_KEY) headers["X-Api-Key"] = API_KEY;

  let response;
  try {
    response = await fetch(`${API_URL}/v1/recipes/search?${params}`, { headers, signal });
  } catch (error) {
    if (error.name === "AbortError") throw error;
    throw new ApiError("Can't reach the server. Check your connection, then try again.", 0);
  }

  if (!response.ok) {
    const message = MESSAGES[response.status] ?? `The server returned an error (${response.status}). Try again in a moment.`;
    throw new ApiError(message, response.status);
  }

  const body = await response.json();
  return { recipes: body.recipes, page: body.page, totalCount: body.total_count };
}
```

- [ ] **Step 5: Implémenter les composants**

`web/src/components/IngredientForm.jsx` :
```jsx
export default function IngredientForm({ value, onChange, onSubmit, atLimit }) {
  const handleSubmit = (event) => {
    event.preventDefault();
    onSubmit();
  };

  return (
    <form className="ingredient-form" onSubmit={handleSubmit}>
      <label htmlFor="ingredient-input">Add an ingredient</label>
      <div className="ingredient-form__row">
        <input
          id="ingredient-input"
          type="text"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="e.g. rice, eggs"
          autoComplete="off"
          disabled={atLimit}
        />
        <button type="submit" disabled={atLimit || value.trim() === ""}>Add</button>
      </div>
      {atLimit && <p className="hint">You've reached 20 ingredients. Remove one to add another.</p>}
    </form>
  );
}
```

`web/src/components/IngredientList.jsx` :
```jsx
export default function IngredientList({ ingredients, onRemove }) {
  if (ingredients.length === 0) {
    return <p className="muted">No ingredients yet. Add what's in your kitchen.</p>;
  }

  return (
    <ul className="chips" aria-label="Your ingredients">
      {ingredients.map((ingredient) => (
        <li key={ingredient} className="chip">
          {ingredient}
          <button type="button" onClick={() => onRemove(ingredient)} aria-label={`Remove ${ingredient}`}>×</button>
        </li>
      ))}
    </ul>
  );
}
```

`web/src/components/RecipeCard.jsx` :
```jsx
export default function RecipeCard({ recipe }) {
  return (
    <article className="recipe-card">
      <img src={recipe.result_image_url} alt={recipe.name} width={320} height={240} loading="lazy" />
      <div className="recipe-card__body">
        <h3>{recipe.name}</h3>
        <p className="recipe-card__meta">
          <span>{recipe.duration_in_mins} min</span>
          {recipe.category && <span>{recipe.category}</span>}
        </p>
        <details>
          <summary>{recipe.ingredients.length} ingredients</summary>
          <ul>
            {recipe.ingredients.map((ingredient, index) => <li key={index}>{ingredient}</li>)}
          </ul>
        </details>
      </div>
    </article>
  );
}
```

`web/src/components/SearchResults.jsx` :
```jsx
import ReactPaginate from "react-paginate";
import RecipeCard from "./RecipeCard.jsx";
import { PER_PAGE } from "../api/recipes.js";

export default function SearchResults({ status, error, result, onPageChange, onRetry }) {
  if (status === "idle") return null;

  if (status === "loading") {
    return <p role="status" className="muted">Searching recipes…</p>;
  }

  if (status === "error") {
    return (
      <div role="alert" className="alert">
        <p>{error}</p>
        <button type="button" onClick={onRetry}>Try again</button>
      </div>
    );
  }

  if (result.totalCount === 0) {
    return <p role="status">No recipe uses these ingredients. Try removing one.</p>;
  }

  const pageCount = Math.ceil(result.totalCount / PER_PAGE);

  return (
    <section aria-labelledby="results-title">
      <h2 id="results-title">
        {result.totalCount} {result.totalCount === 1 ? "recipe" : "recipes"} found
      </h2>
      <div className="recipe-grid">
        {result.recipes.map((recipe) => <RecipeCard key={recipe.id} recipe={recipe} />)}
      </div>
      {pageCount > 1 && (
        <ReactPaginate
          pageCount={pageCount}
          forcePage={result.page - 1}
          onPageChange={({ selected }) => onPageChange(selected + 1)}
          pageRangeDisplayed={2}
          marginPagesDisplayed={1}
          previousLabel="Previous"
          nextLabel="Next"
          containerClassName="pagination"
          activeClassName="is-active"
          disabledClassName="is-disabled"
        />
      )}
    </section>
  );
}
```

`web/src/App.jsx` :
```jsx
import { useCallback, useEffect, useRef, useState } from "react";
import IngredientForm from "./components/IngredientForm.jsx";
import IngredientList from "./components/IngredientList.jsx";
import SearchResults from "./components/SearchResults.jsx";
import { searchRecipes } from "./api/recipes.js";
import { addIngredients, MAX_INGREDIENTS, removeIngredient } from "./lib/ingredients.js";
import "./App.css";

const EMPTY_RESULT = { recipes: [], page: 1, totalCount: 0 };

export default function App() {
  const [ingredients, setIngredients] = useState([]);
  const [draft, setDraft] = useState("");
  const [status, setStatus] = useState("idle");
  const [result, setResult] = useState(EMPTY_RESULT);
  const [error, setError] = useState(null);
  // La dernière requête envoyée : la pagination et « Try again » la rejouent telle quelle.
  const [lastRequest, setLastRequest] = useState(null);
  const inFlight = useRef(null);

  useEffect(() => () => inFlight.current?.abort(), []);

  const load = useCallback(async (request) => {
    inFlight.current?.abort();
    const controller = new AbortController();
    inFlight.current = controller;

    setLastRequest(request);
    setStatus("loading");
    setError(null);

    try {
      setResult(await searchRecipes({ ...request, signal: controller.signal }));
      setStatus("success");
    } catch (caught) {
      if (caught.name === "AbortError") return;
      setError(caught.message);
      setStatus("error");
    }
  }, []);

  const handleAdd = () => {
    setIngredients((list) => addIngredients(list, draft));
    setDraft("");
  };

  const handleSearch = () => {
    const list = addIngredients(ingredients, draft);
    setIngredients(list);
    setDraft("");
    load({ ingredients: list, page: 1 });
  };

  const handleReset = () => {
    inFlight.current?.abort();
    setIngredients([]);
    setDraft("");
    setResult(EMPTY_RESULT);
    setError(null);
    setLastRequest(null);
    setStatus("idle");
  };

  const canSearch = (ingredients.length > 0 || draft.trim() !== "") && status !== "loading";

  return (
    <main className="app">
      <header className="app__header">
        <h1>Futa Recipes</h1>
        <p>Tell us what's in your kitchen. We'll find the recipes that use the most of it.</p>
      </header>

      <section className="panel" aria-labelledby="ingredients-title">
        <h2 id="ingredients-title">What ingredients do you have?</h2>
        <IngredientForm
          value={draft}
          onChange={setDraft}
          onSubmit={handleAdd}
          atLimit={ingredients.length >= MAX_INGREDIENTS}
        />
        <IngredientList
          ingredients={ingredients}
          onRemove={(term) => setIngredients((list) => removeIngredient(list, term))}
        />
        <div className="actions">
          <button type="button" className="primary" onClick={handleSearch} disabled={!canSearch}>
            Find recipes
          </button>
          <button type="button" onClick={handleReset}>Reset</button>
        </div>
      </section>

      <SearchResults
        status={status}
        error={error}
        result={result}
        onPageChange={(page) => load({ ingredients: lastRequest.ingredients, page })}
        onRetry={() => load(lastRequest)}
      />
    </main>
  );
}
```

- [ ] **Step 6: Réécrire les styles**

`web/src/index.css` :
```css
:root {
  --bg: #f6f7f5;
  --surface: #ffffff;
  --text: #1d2321;
  --muted: #5b6662;
  --border: #d6dcd9;
  --chip: #e7ece9;
  --accent: #2f6d4f;
  --on-accent: #ffffff;
  --danger: #b3261e;
  --danger-soft: #fbeae8;
  color-scheme: light dark;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #121615;
    --surface: #1a201e;
    --text: #e6ebe8;
    --muted: #9aa6a1;
    --border: #2e3834;
    --chip: #26302c;
    --accent: #6cc095;
    --on-accent: #0f1a14;
    --danger: #f2a39d;
    --danger-soft: #3a1d1b;
  }
}

*,
*::before,
*::after {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  line-height: 1.5;
}
```

`web/src/App.css` :
```css
.app { max-width: 72rem; margin: 0 auto; padding: 2rem 1rem 4rem; }
.app__header h1 { margin: 0 0 0.25rem; font-size: 2rem; }
.app__header p { margin: 0 0 2rem; color: var(--muted); }

.panel { background: var(--surface); border: 1px solid var(--border); border-radius: 0.5rem; padding: 1.25rem; margin-bottom: 2rem; }
.panel h2 { margin: 0 0 1rem; font-size: 1.25rem; }

.ingredient-form label { display: block; font-weight: 600; margin-bottom: 0.375rem; }
.ingredient-form__row { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.ingredient-form input { flex: 1 1 16rem; min-width: 0; font: inherit; padding: 0.5rem 0.75rem; border: 1px solid var(--border); border-radius: 0.375rem; background: var(--bg); color: var(--text); }

button { font: inherit; padding: 0.5rem 1rem; border: 1px solid var(--border); border-radius: 0.375rem; background: var(--surface); color: var(--text); cursor: pointer; }
button:disabled { cursor: not-allowed; opacity: 0.55; }
button.primary { background: var(--accent); border-color: var(--accent); color: var(--on-accent); font-weight: 600; }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

.chips { list-style: none; display: flex; flex-wrap: wrap; gap: 0.5rem; padding: 0; margin: 1rem 0 0; }
.chip { display: inline-flex; align-items: center; gap: 0.25rem; padding: 0.125rem 0.25rem 0.125rem 0.75rem; border-radius: 999px; background: var(--chip); }
.chip button { padding: 0 0.5rem; border: 0; background: transparent; font-size: 1.125rem; line-height: 1.5; }

.actions { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1.25rem; }
.hint, .muted { color: var(--muted); }
.hint { font-size: 0.875rem; margin: 0.5rem 0 0; }

.alert { padding: 1rem; border: 1px solid var(--danger); border-radius: 0.5rem; background: var(--danger-soft); }
.alert p { margin: 0 0 0.75rem; }

.recipe-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(16rem, 1fr)); gap: 1rem; }
.recipe-card { overflow: hidden; background: var(--surface); border: 1px solid var(--border); border-radius: 0.5rem; }
.recipe-card img { display: block; width: 100%; height: auto; aspect-ratio: 4 / 3; object-fit: cover; background: var(--chip); }
.recipe-card__body { padding: 0.75rem 1rem 1rem; }
.recipe-card h3 { margin: 0 0 0.25rem; font-size: 1rem; }
.recipe-card__meta { display: flex; gap: 0.75rem; margin: 0 0 0.5rem; font-size: 0.875rem; color: var(--muted); }
.recipe-card ul { margin: 0.5rem 0 0; padding-left: 1.25rem; font-size: 0.875rem; }

.pagination { list-style: none; display: flex; flex-wrap: wrap; gap: 0.375rem; padding: 0; margin: 2rem 0 0; }
.pagination a { display: block; padding: 0.375rem 0.75rem; border: 1px solid var(--border); border-radius: 0.375rem; cursor: pointer; }
.pagination .is-active a { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
.pagination .is-disabled a { cursor: not-allowed; opacity: 0.5; }
```

- [ ] **Step 7: Vérifier le succès**

```bash
cd web && npm run lint && npm test && npm run build && cd ..
```
Expected: lint sans erreur ; tous les tests passent (5 fichiers ou moins, 0 échec) ; build réussi.

Si `getByRole("button", { name: "Page 2" })` ne trouve rien, inspecter le rendu de react-paginate 8.3 (`screen.debug()`) et aligner le sélecteur sur l'`aria-label` réellement produit. Ne pas retirer l'assertion.

- [ ] **Step 8: Vérification manuelle dans le navigateur**

```bash
docker compose up -d api && (cd web && npm run dev)
```
Ouvrir http://localhost:5173, ajouter `rice` et `eggs`, lancer la recherche, aller en page 2 puis revenir en page 1 : les résultats changent et le compteur reste identique. Arrêter avec `Ctrl+C` puis `docker compose down`.

- [ ] **Step 9: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 10: Image de production unique et déploiement Docker Compose sur VPS (OPS-02)

**Files:**
- Create: `compose.prod.yml`, `deploy/Caddyfile`, `.env.production.example`
- Modify: `Dockerfile` (étape `web`), `.dockerignore`, `config/environments/production.rb`, `Makefile`, `.gitignore`

**Interfaces:**
- Consumes: build Vite (tâches 8-9), `/up` et configuration SSL (tâche 1), `Recipes::Populator` idempotent (tâche 6).
- Produces: image `futa-recipes:production` (cible par défaut du `Dockerfile`) contenant l'API et le front dans `public/` ; arguments de build `VITE_API_URL`, `VITE_API_KEY` ; pile `compose.prod.yml` (`app`, `db`, `caddy`) pilotée par `.env.production` ; cibles `make secret|prod-build|prod-up|prod-seed|prod-logs|prod-down|prod-backup`.

- [ ] **Step 1: Compiler le front dans l'image**

Dans `Dockerfile`, remplacer la ligne `ARG RUBY_VERSION=3.3.12` par :
```dockerfile
ARG RUBY_VERSION=3.3.12
ARG NODE_VERSION=20.19.5

# ---------- front Vite ----------
FROM docker.io/library/node:${NODE_VERSION}-slim AS web
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
ARG VITE_API_URL=""
ARG VITE_API_KEY=""
RUN VITE_API_URL="${VITE_API_URL}" VITE_API_KEY="${VITE_API_KEY}" npm run build
```

Dans l'étape `build`, juste après `COPY . .`, ajouter :
```dockerfile
COPY --from=web /web/dist ./public
```

Dans `.dockerignore`, ajouter :
```
/web/.env*
/backups/
```

- [ ] **Step 2: Servir le front depuis Rails**

Dans `config/environments/production.rb`, après `config.consider_all_requests_local = false` :
```ruby

  # Le front Vite compilé est copié dans public/ par le Dockerfile et servi par la même origine.
  # Les assets sont suffixés d'une empreinte ; index.html garde un cache court pour que les déploiements se voient vite.
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=300" }
```

- [ ] **Step 3: Écrire la pile de production**

`compose.prod.yml` :
```yaml
name: futa-recipes-prod

services:
  app:
    build:
      context: .
      target: production
      args:
        VITE_API_KEY: ${VITE_API_KEY:-}
    image: futa-recipes:production
    restart: unless-stopped
    env_file: .env.production
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: [ "CMD", "curl", "-fsS", "http://localhost:3000/up" ]
      interval: 10s
      timeout: 3s
      retries: 12
      start_period: 30s

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}" ]
      interval: 5s
      timeout: 3s
      retries: 30

  # HTTPS automatique (Let's Encrypt) pour DOMAIN ; certificat local si DOMAIN=localhost.
  caddy:
    image: caddy:2.11.4-alpine
    restart: unless-stopped
    environment:
      DOMAIN: ${DOMAIN}
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./deploy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      app:
        condition: service_healthy

volumes:
  pgdata:
  caddy_data:
  caddy_config:
```

`deploy/Caddyfile` :
```
{$DOMAIN} {
	encode zstd gzip
	reverse_proxy app:3000
}
```

`.env.production.example` :
```
# Copier en .env.production sur le serveur. Ne jamais versionner le fichier rempli.

# Nom de domaine pointant vers le serveur (enregistrement DNS A/AAAA). "localhost" pour un essai local.
DOMAIN=recipes.example.com

# Base de données. Mot de passe en hexadécimal : il est inséré tel quel dans DATABASE_URL.
POSTGRES_USER=futa
POSTGRES_PASSWORD=remplacer-par-openssl-rand-hex-32
POSTGRES_DB=futa_recipes_production

# Clé Rails : make secret
SECRET_KEY_BASE=remplacer-par-make-secret

RAILS_LOG_LEVEL=info
# RATE_LIMIT_PER_MINUTE=60
# CORS_ORIGINS=https://autre-client.example.com

# Clé d'API optionnelle. Si elle est définie, VITE_API_KEY doit valoir la même chose pour que le front fonctionne,
# ce qui la rend lisible dans le JavaScript : réservé aux déploiements privés.
# API_KEY=
# VITE_API_KEY=
```

Dans `.gitignore`, ajouter `/backups/`.

- [ ] **Step 4: Ajouter les cibles de production**

Dans `Makefile`, sous `RUN := …` :
```make
PROD    := $(COMPOSE) --env-file .env.production -f compose.prod.yml
```
Ajouter `secret prod-build prod-up prod-seed prod-logs prod-down prod-backup` à `.PHONY`, puis :
```make
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
```

- [ ] **Step 5: Essai complet de la pile de production en local**

```bash
cp .env.production.example .env.production
sed -i.bak \
  -e "s/^DOMAIN=.*/DOMAIN=localhost/" \
  -e "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 32)/" \
  -e "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$(openssl rand -hex 64)/" \
  .env.production && rm .env.production.bak
make prod-build && make prod-up
until [ "$(docker compose --env-file .env.production -f compose.prod.yml ps app --format '{{.Health}}')" = "healthy" ]; do sleep 3; done
make prod-seed
curl -ks https://localhost/ | grep -o "<title>.*</title>"
curl -ks "https://localhost/v1/recipes/search?ingredients=rice,eggs&count_per_page=1" | head -c 250; echo
curl -s -o /dev/null -w "http → %{http_code} %{redirect_url}\n" http://localhost/
docker compose --env-file .env.production -f compose.prod.yml exec app id -u
docker image ls futa-recipes:production --format "{{.Size}}"
```
Expected: `<title>Futa Recipes</title>` ; JSON avec `total_count` > 0 ; redirection `308` vers `https://localhost/` ; utilisateur `1000` ; taille de l'image relevée pour le rapport.

- [ ] **Step 6: Nettoyer l'essai**

```bash
docker compose --env-file .env.production -f compose.prod.yml down --volumes
rm .env.production
```

- [ ] **Step 7: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 11: Déploiement Kamal

Kamal s'exécute depuis son image officielle : rien à installer sur le poste. **Aucun déploiement réel dans cette tâche** — il n'y a pas de serveur cible ; la configuration est validée par `kamal config`.

**Files:**
- Create: `config/deploy.yml`, `.kamal/secrets`, `.env.kamal.example`
- Modify: `Makefile`, `.gitignore` (déjà `/.env.kamal` depuis la tâche 1 — vérifier)

**Interfaces:**
- Consumes: image de production (tâche 10), `/up`, `Recipes::Populator` idempotent.
- Produces: service Kamal `futa-recipes`, accessoire `futa-recipes-db` (Postgres 16) ; alias Kamal `console`, `seed`, `logs`, `dbc` ; cibles `make kamal-config|kamal-setup|kamal-deploy|kamal-seed|kamal-logs|kamal-console|kamal-rollback` ; variables `KAMAL` (commande, surchargeable par `KAMAL=kamal`) et `KAMAL_TTY`.

- [ ] **Step 1: Écrire la configuration Kamal**

`config/deploy.yml` :
```yaml
# Toutes les valeurs propres à votre serveur viennent de .env.kamal (voir .env.kamal.example).
service: futa-recipes
image: <%= ENV.fetch("KAMAL_IMAGE") %>

servers:
  web:
    hosts:
      - <%= ENV.fetch("KAMAL_SERVER") %>

ssh:
  user: <%= ENV.fetch("KAMAL_SSH_USER", "root") %>

# kamal-proxy obtient le certificat Let's Encrypt et bascule sans interruption quand /up répond.
proxy:
  ssl: true
  host: <%= ENV.fetch("KAMAL_HOST") %>
  app_port: 3000
  healthcheck:
    path: /up

registry:
  server: <%= ENV.fetch("KAMAL_REGISTRY_SERVER", "ghcr.io") %>
  username: <%= ENV.fetch("KAMAL_REGISTRY_USERNAME") %>
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  arch: <%= ENV.fetch("KAMAL_BUILDER_ARCH", "amd64") %>
  # Construit le répertoire de travail tel quel, modifications non commitées comprises.
  context: .
  args:
    VITE_API_KEY: "<%= ENV.fetch("VITE_API_KEY", "") %>"

env:
  clear:
    RAILS_LOG_LEVEL: info
    RATE_LIMIT_PER_MINUTE: "<%= ENV.fetch("RATE_LIMIT_PER_MINUTE", "60") %>"
  secret:
    - SECRET_KEY_BASE
    - DATABASE_URL
    - API_KEY
    - CORS_ORIGINS

accessories:
  db:
    image: postgres:16-alpine
    host: <%= ENV.fetch("KAMAL_SERVER") %>
    # Exposé uniquement sur la boucle locale du serveur.
    port: "127.0.0.1:5432:5432"
    env:
      clear:
        POSTGRES_USER: futa
        POSTGRES_DB: futa_recipes_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data

aliases:
  console: app exec --interactive --reuse "bin/rails console"
  dbc: app exec --interactive --reuse "bin/rails dbconsole"
  seed: app exec --reuse "bin/rails db:seed"
  logs: app logs -f
```

`.kamal/secrets` :
```
# Kamal résout ces références depuis l'environnement du poste de déploiement (.env.kamal).
# Ce fichier ne contient aucun secret : il est versionné.
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
SECRET_KEY_BASE=$SECRET_KEY_BASE
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=postgres://futa:$POSTGRES_PASSWORD@futa-recipes-db:5432/futa_recipes_production
API_KEY=$API_KEY
CORS_ORIGINS=$CORS_ORIGINS
```

`.env.kamal.example` :
```
# Copier en .env.kamal (ignoré par git) et remplir.

# Serveur Linux joignable en SSH par clé, et nom de domaine pointant vers son IP.
KAMAL_SERVER=203.0.113.10
KAMAL_SSH_USER=root
KAMAL_HOST=recipes.example.com
# amd64 pour la plupart des VPS ; arm64 pour un serveur ARM (Graviton, Ampere).
KAMAL_BUILDER_ARCH=amd64

# Registre d'images. Pour GHCR : jeton GitHub avec le droit write:packages.
KAMAL_IMAGE=ghcr.io/votre-compte/futa-recipes
KAMAL_REGISTRY_SERVER=ghcr.io
KAMAL_REGISTRY_USERNAME=votre-compte
KAMAL_REGISTRY_PASSWORD=remplacer-par-le-jeton

# make secret
SECRET_KEY_BASE=remplacer-par-make-secret
# openssl rand -hex 32 (hexadécimal : inséré tel quel dans DATABASE_URL)
POSTGRES_PASSWORD=remplacer-par-openssl-rand-hex-32

RATE_LIMIT_PER_MINUTE=60
CORS_ORIGINS=
# Clé d'API optionnelle ; si API_KEY est défini, VITE_API_KEY doit avoir la même valeur (visible dans le front).
API_KEY=
VITE_API_KEY=
```

- [ ] **Step 2: Ajouter les cibles Kamal**

Dans `Makefile`, sous `PROD := …` :
```make
KAMAL_VERSION ?= v2.12.0
KAMAL_TTY     ?= -it
# Sur Linux, installer Kamal (gem install kamal) et lancer : make kamal-deploy KAMAL=kamal
KAMAL ?= docker run $(KAMAL_TTY) --rm --env-file .env.kamal \
	-v "$(CURDIR):/workdir" \
	-v /run/host-services/ssh-auth.sock:/run/host-services/ssh-auth.sock \
	-e SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock \
	-v /var/run/docker.sock:/var/run/docker.sock \
	ghcr.io/basecamp/kamal:$(KAMAL_VERSION)
```
Ajouter `kamal-config kamal-setup kamal-deploy kamal-seed kamal-logs kamal-console kamal-rollback` à `.PHONY`, puis :
```make
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
```

- [ ] **Step 3: Valider la configuration**

```bash
cp .env.kamal.example .env.kamal
make kamal-config KAMAL_TTY=
rm .env.kamal
```
Expected: YAML résolu affichant `service: futa-recipes`, `image: ghcr.io/votre-compte/futa-recipes`, le serveur `203.0.113.10`, `proxy.host: recipes.example.com`, l'accessoire `db`, et aucune erreur ERB ni `KeyError`. Si Kamal refuse le dépôt git monté (« dubious ownership »), ajouter à la commande `KAMAL` l'option `-e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0=/workdir` et relancer.

- [ ] **Step 4: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 12: Qualité outillée — RuboCop, Brakeman, couverture, intégration continue (QA-01, QA-02)

**Files:**
- Create: `.rubocop.yml`, `bin/rubocop`, `bin/brakeman`, `.github/workflows/ci.yml`, `.github/dependabot.yml`
- Modify: `Gemfile`, `Gemfile.lock`, `spec/spec_helper.rb`, `Makefile`, tout fichier Ruby signalé par RuboCop

**Interfaces:**
- Consumes: l'ensemble du code des tâches 1 à 11.
- Produces: cibles `make lint|security|coverage` ; workflow GitHub Actions `CI` (jobs `lint`, `test`, `openapi`, `web`, `image`) ; seuil de couverture appliqué quand `CI=true`.

- [ ] **Step 1: Ajouter SimpleCov**

Dans `Gemfile`, groupe `:test` :
```ruby
  gem "simplecov", "~> 1.3", require: false
```
```bash
docker compose run --rm tools bundle lock && make build
```

En tête de `spec/spec_helper.rb`, avant `RSpec.configure` :
```ruby
require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter %w[ /spec/ /config/ /db/ ]
  # Seuil appliqué à la suite complète en CI ; une exécution ciblée (make test ARGS=…) ne l'impose pas.
  minimum_coverage line: 95, branch: 85 if ENV["CI"] == "true"
end
```

- [ ] **Step 2: Configurer RuboCop et Brakeman**

`.rubocop.yml` :
```yaml
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

inherit_mode:
  merge:
    - Exclude

AllCops:
  Exclude:
    - "db/schema.rb"
    - "web/**/*"
    - "tmp/**/*"
    - "coverage/**/*"
```

`bin/rubocop` :
```ruby
#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

# Configuration explicite : évite qu'un .rubocop.yml parent soit pris en compte.
ARGV.unshift("--config", File.expand_path("../.rubocop.yml", __dir__))

load Gem.bin_path("rubocop", "rubocop")
```

`bin/brakeman` :
```ruby
#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

load Gem.bin_path("brakeman", "brakeman")
```

```bash
chmod +x bin/rubocop bin/brakeman
```

Dans `Makefile`, ajouter `lint security coverage` à `.PHONY` et :
```make
lint: ## RuboCop (style Rails omakase)
	$(RUN) bin/rubocop

security: ## Brakeman (analyse de sécurité statique)
	$(RUN) bin/brakeman --no-pager

coverage: ## Suite complète avec seuil de couverture, comme en CI
	$(COMPOSE) run --rm -e RAILS_ENV=test -e CI=true tools bash -c "bin/rails db:create db:schema:load && bundle exec rspec"
```

- [ ] **Step 3: Mettre le code au style**

```bash
docker compose run --rm tools bin/rubocop -A
make lint
make test
```
Expected: `no offenses detected` ; `0 failures`. Les infractions non corrigées automatiquement se corrigent à la main ; ne pas ajouter d'exclusion pour les faire taire.

- [ ] **Step 4: Analyse de sécurité**

Run: `make security`
Expected: `No warnings found`. Tout avertissement se corrige dans le code ou se documente dans `config/brakeman.ignore` avec une justification écrite.

- [ ] **Step 5: Mesurer la couverture**

Run: `make coverage`
Expected: `0 failures` et couverture ≥ 95 % des lignes, ≥ 85 % des branches. En dessous, écrire les specs manquantes pour les lignes signalées dans `coverage/index.html`. Le seuil ne descend pas sous 90 % / 80 %, et toute baisse est signalée dans le rapport final.

- [ ] **Step 6: Écrire l'intégration continue**

`.github/workflows/ci.yml` :
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: RuboCop
        run: bin/rubocop -f github
      - name: Brakeman
        run: bin/brakeman --no-pager

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 20
    env:
      RAILS_ENV: test
      CI: "true"
      POSTGRES_HOST: localhost
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: Base de test
        run: bin/rails db:create db:schema:load
      - name: RSpec
        run: bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/rspec.xml
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage
          path: coverage/

  openapi:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20.19.5
      - name: Lint OpenAPI
        run: npx --yes @redocly/cli@1.34.20 lint docs/v1/openapi.yaml

  web:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: web
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20.19.5
          cache: npm
          cache-dependency-path: web/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm test
      - run: npm run build

  image:
    runs-on: ubuntu-latest
    needs: [ lint, test, openapi, web ]
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - name: Image de production
        uses: docker/build-push-action@v6
        with:
          context: .
          target: production
          push: false
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

`.github/dependabot.yml` :
```yaml
version: 2
updates:
  - package-ecosystem: bundler
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
  - package-ecosystem: npm
    directory: "/web"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
  - package-ecosystem: docker
    directory: "/"
    schedule:
      interval: weekly
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

- [ ] **Step 7: Valider les workflows**

Les jobs ne peuvent pas s'exécuter sans pousser sur GitHub, ce que ce plan ne fait pas. On valide leur syntaxe et on rejoue localement les commandes équivalentes :
```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color
make lint && make security && make coverage && make docs-lint
(cd web && npm ci && npm run lint && npm test && npm run build)
docker build --target production -t futa-recipes:ci .
```
Expected: `actionlint` sans sortie ; toutes les commandes réussissent.

- [ ] **Step 8: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 13: README complet (ID-01)

**Files:**
- Modify: `README.md` (réécrit intégralement)

**Interfaces:**
- Consumes: cibles `make` (tâches 1, 3, 8, 10, 11, 12), variables de 2.6, contrat de 2.4.
- Produces: documentation de référence pour lancer, configurer, utiliser, déployer et dépanner l'application.

- [ ] **Step 1: Écrire le README**

`README.md` :
````markdown
# Futa Recipes

Trouvez les recettes que vous pouvez cuisiner avec ce que vous avez déjà dans votre cuisine.
L'application interroge 10 013 recettes (allrecipes.com) et les classe selon le nombre de vos ingrédients qu'elles utilisent.

- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Développement](#développement)
- [Configuration](#configuration)
- [Utiliser l'API](#utiliser-lapi)
- [Déployer](#déployer)
- [Dépannage](#dépannage)
- [Structure du dépôt](#structure-du-dépôt)
- [Limites connues](#limites-connues)

## Architecture

| Couche | Technologie |
|---|---|
| API | Ruby 3.3 · Rails 7.2 (mode API) · Puma |
| Données | PostgreSQL 16 · extension `pg_trgm` |
| Front | React 18 · Vite 6 |
| Tests | RSpec · committee (contrat OpenAPI) · Vitest · Testing Library |
| Exploitation | Docker · Caddy ou kamal-proxy (HTTPS) · Kamal · GitHub Actions |

```
                ┌──────────── une seule image Docker ────────────┐
navigateur ──▶ Caddy / kamal-proxy ──▶ Rails                     │
  (HTTPS)       │   /                  → front Vite (public/)     │
                │   /up                → contrôle de santé        │
                │   /v1/recipes/search → API JSON ──▶ PostgreSQL  │
                └────────────────────────────────────────────────┘
```

Le front et l'API partagent la même origine, en production comme en développement (le serveur Vite relaie `/v1` vers l'API) : aucune configuration CORS n'est nécessaire.

## Prérequis

| Outil | Version | Utilisé pour |
|---|---|---|
| Docker Desktop, ou Docker Engine + plugin Compose | Compose ≥ 2.24 | API, base de données, tests, production |
| GNU Make | toute version | raccourcis de commandes |
| Node.js | ≥ 18.18 | front en développement uniquement |

Vérifier :
```bash
docker compose version
make --version
node --version
```

> **macOS :** si `docker` est introuvable alors que Docker Desktop tourne, son binaire est dans `~/.docker/bin`.
> Ajoutez `export PATH="$HOME/.docker/bin:$PATH"` à votre `~/.zshrc`, puis ouvrez un nouveau terminal.

Ruby et PostgreSQL n'ont **pas** besoin d'être installés : tout s'exécute dans des conteneurs.

## Démarrage rapide

```bash
git clone <url-du-dépôt> futa-recipes
cd futa-recipes
make setup        # construit l'image, crée la base, charge les 10 013 recettes
make up           # API sur http://localhost:3000
```

La première exécution de `make setup` télécharge les images et installe les gems : comptez quelques minutes.

Dans un second terminal :
```bash
make web-install
make web-dev      # interface sur http://localhost:5173
```

Vérifier que l'API répond :
```bash
curl "http://localhost:3000/v1/recipes/search?ingredients=rice,eggs&count_per_page=2"
```

## Développement

### Commandes

`make help` liste toutes les cibles. Les principales :

| Commande | Effet |
|---|---|
| `make setup` | Première installation (image, base, données) |
| `make up` / `make down` | Démarre / arrête l'API |
| `make build` | Reconstruit l'image après une modification du `Gemfile` |
| `make console` | Console Rails |
| `make shell` | Shell dans le conteneur |
| `make migrate` | Applique les migrations |
| `make seed` | Charge les recettes (sans effet si déjà présentes) |
| `make reset` | Recrée la base de développement et recharge les recettes |
| `make destroy` | Supprime conteneurs **et** données du projet |
| `make test` | Suite RSpec — `make test ARGS="spec/services"` pour cibler |
| `make coverage` | Suite complète avec seuil de couverture (comme la CI) |
| `make lint` / `make security` | RuboCop / Brakeman |
| `make docs` / `make docs-lint` | Documentation Redoc sur http://localhost:8080 / validation OpenAPI |
| `make web-dev` / `make web-test` / `make web-lint` / `make web-build` | Front : serveur, tests, lint, build |

### Tests et qualité

- **API** : `make test`. Les specs de requête valident chaque réponse contre `docs/v1/openapi.yaml` : modifier la forme d'une réponse sans mettre à jour la spécification fait échouer les tests.
- **Front** : `make web-test`.
- **Intégration continue** : `.github/workflows/ci.yml` exécute lint, Brakeman, RSpec avec couverture, validation OpenAPI, tests et build du front, puis construit l'image de production.

### Travailler sans Docker (optionnel)

Avec Ruby 3.3.12 et PostgreSQL 16 installés localement :
```bash
bundle install
POSTGRES_HOST=localhost bin/setup
POSTGRES_HOST=localhost bin/rails server
```
Les identifiants par défaut sont `postgres` / `postgres` ; surchargez-les avec `POSTGRES_USER` et `POSTGRES_PASSWORD`.

## Configuration

Toutes les variables sont optionnelles en développement. Surchargez-les dans `.env` (copié depuis `.env.example`).

| Variable | Environnement | Rôle | Défaut |
|---|---|---|---|
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | développement, test | Connexion à PostgreSQL | `localhost`, `5432`, `postgres`, `postgres` |
| `DATABASE_URL` | production | Connexion à PostgreSQL | **obligatoire** |
| `SECRET_KEY_BASE` | production | Clé secrète Rails (`make secret`) | **obligatoire** |
| `API_KEY` | toutes | Exige l'en-tête `X-Api-Key` si défini | vide : API publique |
| `CORS_ORIGINS` | toutes | Origines tierces autorisées, séparées par des virgules | vide : CORS désactivé |
| `RATE_LIMIT_PER_MINUTE` | toutes | Requêtes par minute et par IP sur `/v1` | `60` |
| `FORCE_SSL`, `ASSUME_SSL` | production | Redirection HTTPS ; TLS terminé par le proxy | `true`, `true` |
| `RAILS_LOG_LEVEL` | production | Niveau de journalisation | `info` |
| `API_PORT` | développement | Port de l'API sur la machine | `3000` |
| `VITE_API_URL` | build du front | URL de l'API si elle n'est pas sur la même origine | vide |
| `VITE_API_KEY` | build du front | Clé envoyée par le front | vide |
| `API_PROXY_TARGET` | Vite (dev) | Cible du relais `/v1` | `http://localhost:3000` |

> **Ne définissez jamais `DATABASE_URL` en développement.** Rails l'appliquerait aussi aux tests, qui effaceraient alors votre base de développement.

> **Clé d'API et front public :** le front s'exécute dans le navigateur, donc `VITE_API_KEY` est lisible par quiconque ouvre le site.
> `API_KEY` protège une API sans front ou un déploiement privé, pas une API consommée par un site public. Pour un site public, laissez-la vide et comptez sur la limitation de débit.

## Utiliser l'API

Spécification complète : `docs/v1/openapi.yaml`, lisible avec `make docs`.

### `GET /v1/recipes/search`

| Paramètre | Type | Règle | Défaut |
|---|---|---|---|
| `ingredients` | chaîne | Termes séparés par des virgules ; 2 à 40 caractères chacun (lettres, chiffres, espace, apostrophe, tiret) ; 20 au maximum | — |
| `page` | entier | ≥ 1 | `1` |
| `count_per_page` | entier | de 1 à 100 | `100` |

Chaque terme est recherché **en mot entier**, sans tenir compte de la casse, au singulier comme au pluriel anglais : `egg` trouve « 2 large eggs » mais pas « 1 eggplant ». Les recettes sont classées par nombre de termes trouvés, puis par identifiant, ce qui garantit une pagination stable.

```bash
curl "http://localhost:3000/v1/recipes/search?ingredients=rice,eggs&page=1&count_per_page=1"
```
```json
{
  "recipes": [
    {
      "id": "3f0e4f7a-1c9b-4d2e-9a51-0b6c2f8d7e41",
      "name": "Egg Fried Rice",
      "duration_in_mins": 25,
      "category": "Fried Rice",
      "result_image_url": "https://…",
      "ingredients": [ "2 cups cooked white rice", "2 eggs, beaten" ]
    }
  ],
  "page": 1,
  "total_count": 812
}
```
(identifiants, noms et total donnés à titre d'illustration)

### Erreurs

Toutes les erreurs partagent la même enveloppe :
```json
{ "error": { "http_code": 422, "id": "validation_failed", "developer_message": "One or more parameters are invalid", "details": { "fields": { "page": [ "must be greater than or equal to 1" ] } } } }
```

| Statut | `id` | Cause |
|---|---|---|
| 401 | `unauthorized` | `API_KEY` est défini et l'en-tête `X-Api-Key` est absent ou faux |
| 422 | `validation_failed` | Paramètre invalide ; détail par champ dans `details.fields` |
| 429 | `rate_limited` | Plus de `RATE_LIMIT_PER_MINUTE` requêtes en une minute depuis la même IP |
| 500 | `generic` | Erreur imprévue ; `details.error_id` permet de retrouver la trace dans les journaux |

## Déployer

| | Option A : Docker Compose sur un VPS | Option B : Kamal |
|---|---|---|
| Où l'on construit | sur le serveur | sur votre poste, image poussée vers un registre |
| HTTPS | Caddy (Let's Encrypt) | kamal-proxy (Let's Encrypt) |
| Mise à jour | quelques secondes d'interruption | sans interruption, avec retour arrière |
| Prérequis | un serveur avec Docker | un serveur SSH, un registre d'images, Docker sur votre poste |

Dans les deux cas, il faut un serveur Linux joignable publiquement, un nom de domaine dont l'enregistrement DNS `A` (ou `AAAA`) pointe vers lui, et les ports **80** et **443** ouverts. Prévoyez au moins 1 vCPU et 2 Go de mémoire si l'image est construite sur le serveur.

### Option A — Docker Compose sur un VPS

**1. Installer Docker sur le serveur** (Ubuntu ou Debian) :
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # puis se reconnecter
sudo apt-get install -y make git
```

**2. Récupérer le code :**
```bash
git clone <url-du-dépôt> futa-recipes && cd futa-recipes
```

**3. Configurer :**
```bash
cp .env.production.example .env.production
openssl rand -hex 32    # → POSTGRES_PASSWORD
make secret             # → SECRET_KEY_BASE
nano .env.production    # renseigner DOMAIN, POSTGRES_PASSWORD, SECRET_KEY_BASE
```

**4. Lancer :**
```bash
make prod-build
make prod-up
docker compose --env-file .env.production -f compose.prod.yml ps   # attendre "healthy" sur app
make prod-seed
```
Caddy obtient le certificat HTTPS au premier accès au domaine.

**5. Vérifier :**
```bash
curl https://votre-domaine/up
curl "https://votre-domaine/v1/recipes/search?ingredients=rice&count_per_page=1"
```

**Mettre à jour :**
```bash
git pull && make prod-build && make prod-up
```
Les migrations s'appliquent au démarrage du conteneur (`db:prepare`). L'application est indisponible pendant son redémarrage, soit quelques secondes.

**Sauvegarder et restaurer :**
```bash
make prod-backup    # → backups/AAAA-MM-JJ-HHMM.sql.gz
gunzip -c backups/<fichier>.sql.gz | docker compose --env-file .env.production -f compose.prod.yml \
  exec -T db sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
```
Copiez régulièrement le dossier `backups/` hors du serveur.

**Exploiter :** `make prod-logs` pour les journaux, `make prod-down` pour arrêter (les données sont conservées dans des volumes Docker).

### Option B — Kamal

Kamal s'exécute depuis son image Docker officielle : rien d'autre à installer sur votre poste.

**1. Préparer les accès :**
- une clé SSH autorisée sur le serveur, chargée dans votre agent : `ssh-add ~/.ssh/id_ed25519` ;
- un registre d'images. Pour GitHub Container Registry, créez un jeton avec le droit `write:packages`.

**2. Configurer :**
```bash
cp .env.kamal.example .env.kamal
make secret               # → SECRET_KEY_BASE
openssl rand -hex 32      # → POSTGRES_PASSWORD
nano .env.kamal           # serveur, domaine, registre, secrets
make kamal-config         # affiche la configuration résolue, sans rien déployer
```

**3. Premier déploiement :**
```bash
make kamal-setup          # installe Docker sur le serveur, démarre Postgres, déploie l'application
make kamal-seed           # charge les recettes
```

**Ensuite :**

| Commande | Effet |
|---|---|
| `make kamal-deploy` | Déploie la version courante, sans interruption |
| `make kamal-rollback VERSION=<version>` | Revient à une version précédente (versions listées par `make kamal-deploy` et dans `kamal app containers`) |
| `make kamal-logs` | Journaux de l'application |
| `make kamal-console` | Console Rails en production |

> **Mac Apple Silicon :** l'image est construite pour `amd64` par émulation, ce qui est lent. Pour un serveur ARM, mettez `KAMAL_BUILDER_ARCH=arm64`.
>
> **Linux :** l'agent SSH de Docker Desktop n'existe pas. Installez Kamal (`gem install kamal -v 2.12.0`), chargez les variables puis lancez-le directement :
> `set -a && . ./.env.kamal && set +a && make kamal-deploy KAMAL=kamal`

## Dépannage

| Symptôme | Solution |
|---|---|
| `docker: command not found` sur macOS | Ajouter `~/.docker/bin` au `PATH` (voir [Prérequis](#prérequis)) |
| `port is already allocated` sur 3000 | Libérer le port, ou `API_PORT=3001` dans `.env` puis `API_PROXY_TARGET=http://localhost:3001` dans `web/.env` |
| Le front affiche « Can't reach the server » | L'API ne tourne pas : `make up` |
| « Too many searches » en développement | Augmenter `RATE_LIMIT_PER_MINUTE` dans `.env`, puis `make down && make up` |
| 401 sur toutes les requêtes | `API_KEY` est défini : envoyer `X-Api-Key`, ou compiler le front avec `VITE_API_KEY` |
| Gem introuvable après modification du `Gemfile` | `make build` |
| `permission denied to create extension "pg_trgm"` sur une base managée | Activer l'extension une fois avec un compte administrateur : `CREATE EXTENSION pg_trgm;` |
| Caddy ou kamal-proxy n'obtient pas de certificat | Vérifier que le DNS pointe vers le serveur et que les ports 80 et 443 sont ouverts |
| Tout remettre à zéro en local | `make destroy && make setup` |

## Structure du dépôt

```
app/
  contracts/v1/recipes/   validation des paramètres (dry-validation)
  controllers/            ApplicationController (erreurs), v1/ (API), concerns/authorizable.rb
  errors/api_errors/      erreurs sérialisées en JSON
  models/                 Recipe, RecipeIngredient
  services/recipes/       Searcher (recherche SQL), Populator (amorçage), IngredientList
  views/v1/recipes/       sérialisation JSON (jb)
config/deploy.yml         configuration Kamal
db/data/recipes-en.json   jeu de données (10 013 recettes)
deploy/Caddyfile          HTTPS pour Docker Compose
docs/v1/openapi.yaml      contrat de l'API
spec/                     tests RSpec
web/                      front React + Vite
compose.yml               développement
compose.prod.yml          production sur VPS
Dockerfile                images de développement et de production
Makefile                  toutes les commandes
```

## Limites connues

- La recherche ne neutralise pas les accents et son heuristique singulier/pluriel ne vaut que pour l'anglais. `berry` ne trouve pas `blueberries`.
- Le compteur de limitation de débit vit en mémoire dans chaque processus : avec plusieurs serveurs ou processus Puma, la limite s'applique par processus.
- La clé d'API ne protège pas une API consommée par le front public (voir [Configuration](#configuration)).
- Le jeu de données est figé ; les images pointent vers un CDN tiers et peuvent disparaître.

## Données

Recettes issues de [allrecipes.com](https://www.allrecipes.com), fournies à des fins de démonstration uniquement.
````

- [ ] **Step 2: Vérifier chaque commande citée**

```bash
grep -oE "make [a-z-]+" README.md | sort -u | while read -r _ target; do
  grep -qE "^${target}:" Makefile || echo "cible absente : ${target}"
done
```
Expected: aucune sortie.

- [ ] **Step 3: Point d'arrêt (pas de commit)**

```bash
git status --short && git diff --stat
```

### Task 14: Vérification finale de bout en bout

Aucun fichier du dépôt n'est modifié ici. Cette tâche produit le rapport rendu à l'utilisateur, en citant les sorties réelles.

**Files:**
- Aucun (copie de travail temporaire hors dépôt).

**Interfaces:**
- Consumes: tout.
- Produces: rapport de vérification.

- [ ] **Step 1: Démarrage « nouvel arrivant » depuis une copie propre**

Simule un utilisateur qui suit le README sans rien avoir sur sa machine, dans un projet Compose distinct pour ne pas toucher à la base de développement :
```bash
FRESH=$(mktemp -d)/futa-recipes
rsync -a --exclude .git --exclude .env --exclude web/node_modules --exclude web/dist --exclude coverage --exclude tmp --exclude log ./ "$FRESH/"
cd "$FRESH"
export COMPOSE_PROJECT_NAME=futa-recipes-fresh API_PORT=3100
time make setup
docker compose up -d api
until curl -fsS http://localhost:3100/up >/dev/null; do sleep 2; done
curl -s "http://localhost:3100/v1/recipes/search?ingredients=rice,eggs&count_per_page=2" | head -c 300; echo
```
Expected: `make setup` réussit sans autre intervention ; la recherche renvoie du JSON. Relever la durée de `make setup`.

- [ ] **Step 2: Constats de l'audit, vérifiés sur les données réelles**

Toujours dans la copie propre :
```bash
API=http://localhost:3100/v1/recipes/search
code() { curl -s -o /dev/null -w "%{http_code}" "$API?$1"; }
echo "API-03 page=0            → $(code 'ingredients=rice&page=0')   (attendu 422 ; avant : dernière page)"
echo "API-03 count_per_page=0  → $(code 'ingredients=rice&count_per_page=0')   (attendu 422 ; avant : 500)"
echo "API-03 count_per_page=1e7→ $(code 'ingredients=rice&count_per_page=10000000')   (attendu 422 ; avant : 10 M d'entrées allouées)"
echo "Regex                    → $(code 'ingredients=rice.*')   (attendu 422)"

docker compose run --rm tools bin/rails runner '
  ids = ->(page) { Recipes::Searcher.new(ingredients: %w[ egg ], page:, count_per_page: 50).search.first.map(&:id) }
  puts "PERF-02 même page deux fois identique : #{ids.(3) == ids.(3)}"

  _, _, total = Recipes::Searcher.new(ingredients: %w[ garlic ginger ], count_per_page: 100).search
  all = (1..(total / 100.0).ceil).flat_map { |page| Recipes::Searcher.new(ingredients: %w[ garlic ginger ], page:, count_per_page: 100).search.first.map(&:id) }
  puts "PERF-02 parcours complet : #{all.size} vus / #{total} attendus / #{all.uniq.size} distincts"

  recipes = Recipes::Searcher.new(ingredients: %w[ egg ], count_per_page: 100).search.first
  false_positives = recipes.reject { |recipe| recipe.recipe_ingredients.any? { |i| i.ingredient_description =~ /\beggs?\b/i } }
  puts "PERF-03 faux positifs pour egg (sur 100) : #{false_positives.size}"

  timings = 20.times.map do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Recipes::Searcher.new(ingredients: %w[ salt sugar butter ], count_per_page: 20).search
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
  end.sort
  puts "PERF-01 salt,sugar,butter : médiane #{timings[10].round} ms, max #{timings.last.round} ms"
'
```
Expected: quatre `422` ; `true` ; `vus = attendus = distincts` ; `0` faux positif ; médiane relevée pour le rapport.

- [ ] **Step 3: Nettoyer la copie propre**

```bash
docker compose down --volumes
cd - && rm -rf "$(dirname "$FRESH")"
unset COMPOSE_PROJECT_NAME API_PORT
```

- [ ] **Step 4: Suites, lint et sécurité dans le dépôt**

```bash
make coverage
make lint
make security
make docs-lint
(cd web && npm ci && npm run lint && npm test && npm run build)
```
Expected: tout réussit ; relever le nombre d'examples, les couvertures ligne et branche, le nombre de tests front.

- [ ] **Step 5: Pile de production et Kamal**

Rejouer les étapes 5 et 6 de la tâche 10, puis l'étape 3 de la tâche 11. Relever la taille de l'image de production.

- [ ] **Step 6: Contrôle de périmètre**

```bash
git status --short
git diff --stat main
grep -rn "pennylane\|Pennylane\|Src::\|module Src" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=docs . || echo "aucune trace de l'ancienne identité"
```
Expected: aucune trace hors `docs/superpowers/` (qui cite l'audit) ; rien n'est commité.

- [ ] **Step 7: Rapport à l'utilisateur**

Tableau des 21 constats avec, pour chacun : corrigé / partiellement / non, et la preuve (spec, commande, sortie). Puis ce qui n'a pas pu être vérifié : exécution GitHub Actions, déploiement réel sur un serveur, émission d'un certificat Let's Encrypt public. Et les écarts éventuels par rapport à ce plan, avec leur raison.

