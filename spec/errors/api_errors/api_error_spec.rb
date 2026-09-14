require "rails_helper"

RSpec.describe ApiErrors::ApiError do
  it "sérialise chaque sous-classe avec l'enveloppe commune (régression API-01)" do
    errors = [
      ApiErrors::GenericError.new,
      ApiErrors::ResourceNotFoundError.new("Couldn't find Recipe"),
      ApiErrors::ValidationError.new(page: [ "must be greater than or equal to 1" ]),
      ApiErrors::UnauthorizedError.new,
      ApiErrors::TooManyRequestsError.new
    ]

    expect(errors.map { |error| error.as_json.keys }.uniq).to eq([ %i[ http_code id developer_message details ] ])
    expect(errors.map(&:http_code)).to eq([ 500, 404, 422, 401, 429 ])
    expect(errors.map(&:id)).to eq(%w[ generic resource_not_found validation_failed unauthorized rate_limited ])
  end

  it "utilise developer_message comme message d'exception" do
    expect(ApiErrors::ResourceNotFoundError.new.message).to eq("The requested resource does not exist")
  end
end
