FactoryBot.define do
  factory :recipe do
    sequence(:name) { |n| "Recipe #{n}" }
    category { "Main Dishes" }
    sequence(:result_image_url) { |n| "https://images.example.com/recipes/#{n}.jpg" }
    duration_in_mins { 30 }
  end
end
