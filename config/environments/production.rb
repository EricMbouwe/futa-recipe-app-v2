require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Le front Vite compilé est copié dans public/ par le Dockerfile et servi par la même origine.
  # Les assets sont suffixés d'une empreinte ; index.html garde un cache court pour que les déploiements se voient vite.
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=300" }

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
