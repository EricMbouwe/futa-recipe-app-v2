module ApiErrors
  class UnauthorizedError < ApiError
    def initialize
      super(
        http_code: 401,
        id: "unauthorized",
        developer_message: "A valid X-Api-Key header is required",
        details: {}
      )
    end
  end
end
