require "rails_helper"

RSpec.describe "GET /up", type: :request do
  it "répond 200 quand l'application a démarré" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
