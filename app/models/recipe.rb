class Recipe < ApplicationRecord
  attribute :name, :string
  attribute :category, :string
  attribute :result_image_url, :string
  attribute :duration_in_mins, :integer

  has_many :recipe_ingredients
end
