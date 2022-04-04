source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.3'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 6.1.4', '>= 6.1.4.1'
# Use postgresql as the database for Active Record
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
gem 'bcrypt', '~> 3.1.7'
# Use Active Storage variant
# gem 'image_processing', '~> 1.2'
# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false
gem 'dry-types', '~> 1.4.0'
gem 'dry-validation', '~> 1.5.0'
gem 'jb', '~> 0.8.0'
gem "jsonb_accessor"
gem 'json-schema'
gem 'money'
gem 'money-rails', '~>1.12'
gem 'oj', '~> 3.10.5'
gem 'pgreset'
gem 'pg', '>= 0.18', '< 2.0'
gem 'pry-rails'
# Use Puma as the app server
gem 'puma', '~> 5.0'
gem 'rack-cors'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'awesome_print'
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # A library for generating fake data such as names, addresses, and phone
  gem 'faker', :git => 'https://github.com/faker-ruby/faker.git', :branch => 'master'
  # A library for setting up Ruby objects as test data.
  gem 'factory_bot_rails'
  # Rspec
  gem 'rspec-rails', '~> 5.0.0'
end

group :development do
  gem 'listen', '~> 3.3'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

group :test do
  gem 'rspec_junit_formatter'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
