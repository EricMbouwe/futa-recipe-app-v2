module Recipes
  # Transforme la saisie brute "Rice, bread,,rice" en [ "rice", "bread" ].
  module IngredientList
    SEPARATOR = ","

    def self.parse(raw)
      raw.to_s.split(SEPARATOR).map { |term| term.squish.downcase }.compact_blank.uniq
    end
  end
end
