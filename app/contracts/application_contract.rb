class ApplicationContract < Dry::Validation::Contract
  def self.validate!(data)
    result = self.new.call(data)

    raise ApiErrors::ValidationError.new(result.errors.to_h) unless result.success?

    result.to_h
  end
end
