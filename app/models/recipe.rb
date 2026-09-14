class Recipe < ApplicationRecord
  has_many :recipe_ingredients, dependent: :delete_all, inverse_of: :recipe

  validates :name, :result_image_url, presence: true
  validates :category, exclusion: { in: [ nil ], message: "can't be nil" }
  validates :duration_in_mins, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
