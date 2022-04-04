module V1
    class RecipesController < AppController
        def search
          ingredients = params[:ingredients].downcase.split(',') rescue []
          page = params[:page]&.to_i rescue nil
          count_per_page = params[:count_per_page]&.to_i rescue nil

          @recipes, @page, @total_count = Recipes::Searcher.new(
            ingredients: ingredients,
            page: page,
            count_per_page: count_per_page,
          ).search
        end
    end
end
