# Le compteur de débit est partagé par le processus : chaque spec de requête repart de zéro.
RSpec.configure do |config|
  config.before(type: :request) { Rails.configuration.x.rate_limit_store.clear }
end
