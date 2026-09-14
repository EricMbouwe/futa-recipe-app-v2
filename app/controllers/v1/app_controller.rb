module V1
  class AppController < ApplicationController
    # Déclarée avant Authorizable : les tentatives de clé sont elles aussi comptées.
    rate_limit to: Rails.configuration.x.rate_limit_per_minute,
      within: 1.minute,
      store: Rails.configuration.x.rate_limit_store,
      with: -> { raise ApiErrors::TooManyRequestsError }

    include Authorizable
  end
end
