FactoryBot.define do
  factory :recipe do
    name { Faker::Name.name }
    category { Faker::Name.name }
    result_image_url { Faker::Company.logo }
    duration_in_mins { Faker::Name.name.size * 5 }
  end
end
