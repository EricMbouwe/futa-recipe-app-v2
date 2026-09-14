module V1
  module Recipes
    class SearchContract < ApplicationContract
      MAX_INGREDIENTS = 20
      MAX_COUNT_PER_PAGE = 100
      MAX_REPORTED_INVALID = 5
      # 2 à 40 caractères : lettres, chiffres, espace, apostrophe, tiret ; commence par une lettre ou un chiffre.
      # Aucun métacaractère d'expression régulière ne peut passer (la recherche construit des motifs PostgreSQL).
      INGREDIENT_FORMAT = /\A[\p{L}\p{N}][\p{L}\p{N} '\-]{1,39}\z/

      params do
        optional(:ingredients).maybe(:string)
        optional(:page).filled(:integer, gteq?: 1)
        optional(:count_per_page).filled(:integer, gteq?: 1, lteq?: MAX_COUNT_PER_PAGE)
      end

      rule(:ingredients) do
        next if value.nil?

        terms = ::Recipes::IngredientList.parse(value)
        invalid = terms.grep_v(INGREDIENT_FORMAT)

        if terms.size > MAX_INGREDIENTS
          key.failure("must contain at most #{MAX_INGREDIENTS} ingredients")
        elsif invalid.any?
          key.failure("contains invalid ingredients: #{invalid.first(MAX_REPORTED_INVALID).join(', ')}")
        end
      end
    end
  end
end
