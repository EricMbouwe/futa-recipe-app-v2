source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.3"
# json 3.0 a supprimé la tolérance de la clé quirks_mode encore envoyée par
# ActiveSupport::JSON.encode (Rails 7.2.3.2), ce qui lève une ArgumentError ;
# on reste sur la dernière série 2.x, compatible.
gem "json", "~> 2.9"
gem "pg", "~> 1.6"
gem "puma", "~> 6.6"
gem "bootsnap", require: false
gem "dry-validation", "~> 1.11"
gem "jb", "~> 0.8.2"
gem "rack-cors", "~> 3.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "factory_bot_rails", "~> 6.5"
  gem "rspec-rails", "~> 8.0"
end

group :test do
  gem "committee-rails", "~> 0.10"
  gem "rspec_junit_formatter", "~> 0.6"
  gem "simplecov", "~> 1.3", require: false
end
