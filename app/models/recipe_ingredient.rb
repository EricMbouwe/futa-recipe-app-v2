class RecipeIngredient < ApplicationRecord
  attribute :ingredient_description, :string

  belongs_to :recipe
end
