FactoryBot.define do
  factory :recipe_ingredient do
    recipe
    ingredient_description { Faker::Name.name }
  end
end
