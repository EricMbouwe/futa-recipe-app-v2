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
