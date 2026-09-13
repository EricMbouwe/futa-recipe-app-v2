module ApiErrors
  class ValidationError < ApiError
    # fields - Hash { champ => [messages] } tel que produit par dry-validation.
    def initialize(fields)
      super(
        http_code: 422,
        id: "validation_failed",
        developer_message: "One or more parameters are invalid",
        details: { fields: }
      )
    end
  end
end
