module ApiErrors
  class ResourceNotFoundError < ApiError
    def initialize(message = "Resource not found")
      super(
        http_code: 404,
        id: "resource_not_found",
        developer_message: "The requested resource does not exist",
        details: { message: }
      )
    end
  end
end
