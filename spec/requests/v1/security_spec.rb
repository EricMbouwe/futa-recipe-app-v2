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
    it "renvoie 429 au-delà de la limite par minute, sans clé d'API" do
      limit = Rails.configuration.x.rate_limit_per_minute
      limit.times { get url }
      expect(response).to have_http_status(200)

      get url

      expect(response).to have_http_status(429)
      assert_response_schema_confirm(429)
      expect(body.dig("error", "id")).to eq("rate_limited")
    end

    context "quand API_KEY est défini" do
      around do |example|
        Rails.configuration.x.api_key = "s3cr3t-key"
        example.run
      ensure
        Rails.configuration.x.api_key = nil
      end

      it "compte les tentatives de clé invalide dans la limite par minute" do
        limit = Rails.configuration.x.rate_limit_per_minute
        limit.times do
          get url, headers: { "X-Api-Key" => "wrong" }
          expect(response).to have_http_status(401)
        end

        get url, headers: { "X-Api-Key" => "wrong" }

        expect(response).to have_http_status(429)
      end
    end
  end

  describe "CORS" do
    it "n'autorise aucune origine tierce par défaut (régression SEC-01)" do
      get url, headers: { "Origin" => "https://evil.example" }

      expect(response.headers.to_h.keys.map(&:downcase)).not_to include("access-control-allow-origin")
    end
  end
end
