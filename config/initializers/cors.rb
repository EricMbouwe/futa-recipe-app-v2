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
