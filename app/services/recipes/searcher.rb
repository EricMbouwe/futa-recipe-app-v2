module Recipes
  class Searcher
    DEFAULT_COUNT_PER_PAGE = 100
    DEFAULT_PAGE = 1
    attr_reader :ingredients, :count_per_page, :page

    # Initialize a new CustomerAccounts::Creator.
    #
    # ingredients - The Array of String with ingredients to search recipes.
    # count_per_page - The Integer with the total of Recipes to return.
    # page - The Integer with cursor of where to start.
    #
    def initialize(ingredients:, count_per_page: nil, page: nil)
      @ingredients = ingredients
      @count_per_page = count_per_page ? count_per_page : DEFAULT_COUNT_PER_PAGE
      @page = page ? page : DEFAULT_PAGE
    end

    # Search recipes that contain ingredients.
    #
    # Returns:
    #   - An Array of Recipes ordered by recipe that contains most ingredient first
    #   - An Integer with the current page.
    #   - An Integer with the total found.
    def search
      return [], page, 0  unless ingredients.present?

      current_recipes = current_ordered_recipe_ids.map do |recipe_id|
        current_recipe_by_ids[recipe_id]
      end

      return current_recipes, page, ordered_recipe_ids.count
    end

    private

    def current_recipe_by_ids
      @current_recipe_by_ids ||= begin
        return {} unless current_ordered_recipe_ids.any?

        Recipe.includes(:recipe_ingredients).where(id: current_ordered_recipe_ids).index_by(&:id)
      end
    end

    def current_ordered_recipe_ids
      @current_ordered_recipe_ids ||= begin
        recipe_ids_in_groups = ordered_recipe_ids.in_groups_of(count_per_page)

        page <= recipe_ids_in_groups.count ? recipe_ids_in_groups[page - 1].compact : []
      end
    end

    def ordered_recipe_ids
      @ordered_recipe_ids ||= begin
        recipe_ingredients.group_by(&:recipe_id).values.map do |ing_group|
          ingredient_descriptions = ing_group.map(&:ingredient_description).join(",")

          ingredient_matches_count = ingredients.select do |ingredient|
            ingredient_descriptions.include?(ingredient)
          end.count

          {
            recipe_id: ing_group.first.recipe_id,
            ingredient_matches_count:  ingredient_matches_count,
          }
        end.sort_by{ |data| -data[:ingredient_matches_count] }.
        map{ |data| data[:recipe_id]}
      end
    end

    def recipe_ingredients
      query = nil

      ingredients.each do |ingredient|
        query = query ? query.or(RecipeIngredient.where("ingredient_description LIKE ?", "%#{ingredient}%")) :
                        RecipeIngredient.where("ingredient_description LIKE ?", "%#{ingredient}%")
      end

      query
    end
  end
end
