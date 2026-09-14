module Recipes
  # Recherche des recettes contenant des ingrédients, entièrement en SQL :
  # filtre indexé (pg_trgm), score, ordre total et pagination côté base.
  class Searcher
    DEFAULT_COUNT_PER_PAGE = 100
    DEFAULT_PAGE = 1

    attr_reader :ingredients, :count_per_page, :page

    # Motif d'expression régulière PostgreSQL (ARE) pour un terme, en mot entier,
    # au singulier ou au pluriel anglais : "egg" → \megg(s|es)?\M, "berry" → \mberr(y|ies)\M.
    def self.pattern_for(ingredient)
      singular = ingredient.singularize

      stem, suffix =
        if singular.end_with?("y")
          [ singular.delete_suffix("y"), "(y|ies)" ]
        else
          [ singular, "(s|es)?" ]
        end

      "\\m#{Regexp.escape(stem)}#{suffix}\\M"
    end

    # ingredients    - Array de String normalisés (voir Recipes::IngredientList).
    # count_per_page - Integer, taille de page (défaut 100).
    # page           - Integer, à partir de 1 (défaut 1).
    def initialize(ingredients:, count_per_page: nil, page: nil)
      @ingredients = ingredients
      @count_per_page = count_per_page || DEFAULT_COUNT_PER_PAGE
      @page = page || DEFAULT_PAGE
    end

    # Renvoie [ recettes de la page, page, nombre total de recettes trouvées ].
    def search
      return [ [], page, 0 ] if ingredients.empty?

      [ recipes_for_page, page, total_count ]
    end

    private

    def recipes_for_page
      ids = matching_ingredients
        .group(:recipe_id)
        .select(:recipe_id, "#{score_sql} AS score")
        .order(Arel.sql("score DESC"), :recipe_id)
        .limit(count_per_page)
        .offset((page - 1) * count_per_page)
        .map(&:recipe_id)

      recipes_by_id = Recipe.includes(:recipe_ingredients).where(id: ids).index_by(&:id)
      ids.map { |id| recipes_by_id.fetch(id) }
    end

    def total_count
      matching_ingredients.distinct.count(:recipe_id)
    end

    def matching_ingredients
      RecipeIngredient.where("recipe_ingredients.ingredient_description ~* ANY (ARRAY[?])", patterns)
    end

    # Une recette gagne un point par terme trouvé, quel que soit le nombre de lignes qui le contiennent.
    def score_sql
      patterns.map do |pattern|
        RecipeIngredient.sanitize_sql_array([ "bool_or(recipe_ingredients.ingredient_description ~* ?)::int", pattern ])
      end.join(" + ")
    end

    def patterns
      @patterns ||= ingredients.map { |ingredient| self.class.pattern_for(ingredient) }
    end
  end
end
