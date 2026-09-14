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

Toutes les variables sont optionnelles en développement. Le fichier où les surcharger dépend de ce qu'elles configurent : `.env` (racine, copié depuis `.env.example`) pour l'API — `API_PORT`, `API_KEY`, `CORS_ORIGINS`, `RATE_LIMIT_PER_MINUTE` ; `web/.env` (copié depuis `web/.env.example`) pour le build du front — `VITE_API_URL`, `VITE_API_KEY`, `API_PROXY_TARGET` ; `.env.production` ou `.env.kamal` en production (voir [Déployer](#déployer)).

| Variable | Environnement | Rôle | Défaut |
|---|---|---|---|
| `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | développement, test | Connexion à PostgreSQL. Sous Docker, `compose.yml` les fixe à `db` / `postgres` / `postgres` pour l'API et pour toute commande `make` (console, test…) : le contenu de `.env` est ignoré. Ne comptent que sans Docker (voir « Travailler sans Docker ») ou en CI | `localhost`, `postgres`, `postgres` |
| `POSTGRES_PORT` | développement, test | Port de connexion à PostgreSQL. `compose.yml` ne le fixe pas comme les trois variables ci-dessus, mais le conteneur `db` écoute toujours sur `5432` à l'intérieur du réseau Docker : ne le changez que si vous travaillez sans Docker | `5432` |
| `DATABASE_URL` | production | Connexion à PostgreSQL, prioritaire sur les variables `POSTGRES_*` ci-dessous | l'une des deux options est **obligatoire** |
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | production | Connexion à PostgreSQL si `DATABASE_URL` n'est pas définie | `POSTGRES_HOST` : `localhost`, `POSTGRES_PORT` : `5432` ; les autres sont obligatoires dans ce cas |
| `SECRET_KEY_BASE` | production | Clé secrète Rails (`make secret`) | **obligatoire** |
| `API_KEY` | toutes | Exige l'en-tête `X-Api-Key` si défini | vide : API publique |
| `CORS_ORIGINS` | toutes | Origines tierces autorisées, séparées par des virgules | vide : CORS désactivé |
| `RATE_LIMIT_PER_MINUTE` | toutes | Requêtes par minute et par IP sur `/v1` | `60` |
| `FORCE_SSL`, `ASSUME_SSL` | production | Redirection HTTPS ; TLS terminé par le proxy | `true`, `true` |
| `RAILS_LOG_LEVEL` | production | Niveau de journalisation | `info` |
| `API_PORT` | développement | Port de l'API sur la machine | `3000` |
| `DOCS_PORT` | développement (Compose) | Port de Redoc (`make docs`), dans `.env` racine | `8080` |
| `VITE_API_URL` | build du front | URL de l'API si elle n'est pas sur la même origine — dans `web/.env`, pas dans le `.env` de la racine | vide |
| `VITE_API_KEY` | build du front | Clé envoyée par le front — dans `web/.env` | vide |
| `API_PROXY_TARGET` | Vite (dev) | Cible du relais `/v1` — dans `web/.env` | `http://localhost:3000` |

> **Ne définissez jamais `DATABASE_URL` en développement.** Rails l'appliquerait aussi aux tests, qui effaceraient alors votre base de développement.

> **Mot de passe et `DATABASE_URL` :** cette variable est une URL ; les caractères réservés (`:`, `/`, `@`, `?`, `#`) doivent y être encodés en pourcentage. Avec les variables séparées `POSTGRES_*`, ces caractères n'ont pas besoin d'encodage puisqu'elles ne passent pas par un analyseur d'URL — mais ce n'est pas une garantie que tout caractère fonctionne partout (shell, fichier `.env`, etc.).

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
Cette option utilise toujours les variables `POSTGRES_*` (pas `DATABASE_URL`) : `compose.prod.yml` fixe `POSTGRES_HOST=db` et lit le reste dans `.env.production`.

**4. Lancer :**
```bash
make prod-build
make prod-up
docker compose --env-file .env.production -f compose.prod.yml ps   # attendre "healthy" sur app
make prod-seed
```
Les recettes se chargent automatiquement au premier démarrage du conteneur (`db:prepare`) ; `make prod-seed` sert de filet et n'a aucun effet si elles le sont déjà. Caddy obtient le certificat HTTPS au premier accès au domaine.

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
`KAMAL_IMAGE` ne doit **pas** inclure l'hôte du registre : Kamal le préfixe lui-même avec `KAMAL_REGISTRY_SERVER` (par exemple `votre-compte/futa-recipes` devient `ghcr.io/votre-compte/futa-recipes`). Cette option utilise elle aussi les variables `POSTGRES_*`, jamais `DATABASE_URL` : `config/deploy.yml` fixe `POSTGRES_HOST=futa-recipes-db`, `POSTGRES_USER=futa` et `POSTGRES_DB=futa_recipes_production` en clair, `POSTGRES_PASSWORD` restant un secret.

**3. Premier déploiement :**
```bash
make kamal-setup          # installe Docker sur le serveur, démarre Postgres, déploie l'application
make kamal-seed           # charge les recettes
```
Les recettes se chargent automatiquement au premier démarrage du conteneur (`db:prepare`) ; `make kamal-seed` sert de filet et n'a aucun effet si elles le sont déjà.

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
- Rails 7.2 ne reçoit plus de correctifs de sécurité depuis le 09/08/2026 ; `config/brakeman.ignore` neutralise cet avertissement Brakeman pour que la CI reste au vert. La prochaine étape est une mise à niveau vers Rails 8.x.
- `VITE_API_KEY` est passé comme argument de build Docker (front) : il reste visible dans les couches de l'image (BuildKit avertit à ce sujet), en plus d'être lisible dans le JavaScript livré au navigateur (voir [Configuration](#configuration)).

## Données

Recettes issues de [allrecipes.com](https://www.allrecipes.com), fournies à des fins de démonstration uniquement.
