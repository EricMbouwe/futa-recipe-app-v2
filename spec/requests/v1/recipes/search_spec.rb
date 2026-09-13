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
end
