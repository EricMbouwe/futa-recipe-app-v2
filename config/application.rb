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

    # Clé d'API optionnelle : si elle est vide, l'API est publique.
    config.x.api_key = ENV["API_KEY"].presence
    # Requêtes par minute et par IP sur /v1. Compteur en mémoire, propre à chaque processus Puma.
    # Absente ou vide -> 60 ; une valeur non numérique doit toujours faire échouer le démarrage.
    config.x.rate_limit_per_minute = Integer(ENV["RATE_LIMIT_PER_MINUTE"].presence || 60)
    config.x.rate_limit_store = ActiveSupport::Cache::MemoryStore.new
  end
end
