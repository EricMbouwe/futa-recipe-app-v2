# syntax=docker/dockerfile:1
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
COPY --from=web /web/dist ./public
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
