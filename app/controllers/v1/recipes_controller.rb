module V1
  class RecipesController < AppController
    def search
      input = V1::Recipes::SearchContract.validate!(search_params.to_h)

      @recipes, @page, @total_count = ::Recipes::Searcher.new(
        ingredients: ::Recipes::IngredientList.parse(input[:ingredients]),
        page: input[:page],
        count_per_page: input[:count_per_page]
      ).search
    end

    private

    def search_params
      params.permit(:ingredients, :page, :count_per_page)
    end
  end
end
