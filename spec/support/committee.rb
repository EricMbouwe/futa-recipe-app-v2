# Les réponses réelles sont validées directement contre docs/v1/openapi.yaml.
RSpec.configure do |config|
  config.add_setting :committee_options
  config.committee_options = {
    schema_path: Rails.root.join("docs/v1/openapi.yaml").to_s,
    prefix: "/v1",
    strict_reference_validation: true,
    parse_response_by_content_type: true
  }

  config.include Committee::Rails::Test::Methods, type: :request
end
