RSpec::Matchers.define :match_response_schema do |schema|
  match do |response|
    # https://github.com/ruby-json-schema/json-schema#validation
    JSON::Validator.validate!(
      schema,
      JSON.parse(response.body),
      strict: true
    )
  end
end
