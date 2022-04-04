require 'rails_helper'

describe 'GET v1/recipes/search', type: :request do
  let(:headers) do
    {
      'CONTENT-TYPE': 'application/json',
    }
  end

  let(:schema) { load_schema_get('/recipes/search', 'v1') }

  let(:body_response) { JSON.parse(response.body, symbolize_names: true) }

  let(:url) { "#{search_v1_recipes_url}?ingredients=rice,bread&page=1&count_per_page=10"}


  context 'when success' do
    before do
      create(:recipe, name: 'recipe_1').tap do |recipe|
        ['1/2 cup of rice', 'half bread', '1 cup water'].each do |ing_desc|
          create(
            :recipe_ingredient,
            recipe: recipe,
            ingredient_description: ing_desc,
          )
        end
      end
    end

    let(:res_schema) { schema['responses']['200'] }

    it 'returns status code 200' do
      get(url, headers: headers)

      expect(response).to have_http_status(200)
      expect(response).to match_response_schema(res_schema)
    end

    context 'when no query params are not provided' do
      it 'returns status code 200' do
        get(search_v1_recipes_url, headers: headers)

        expect(response).to have_http_status(200)
        expect(response).to match_response_schema(res_schema)
      end
    end

    context 'when some query params are not provided' do
      let(:url) { "#{search_v1_recipes_url}?ingredients=rice,bread&page=1"}
      it 'returns status code 200' do
        get(url, headers: headers)

        expect(response).to have_http_status(200)
        expect(response).to match_response_schema(res_schema)
      end
    end
  end
end