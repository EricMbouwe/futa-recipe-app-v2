FactoryBot.define do
  factory :recipe_ingredient do
    recipe
    ingredient_description { "1 cup water" }
  end
end
