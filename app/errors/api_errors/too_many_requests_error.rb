module ApiErrors
  class TooManyRequestsError < ApiError
    def initialize
      super(
        http_code: 429,
        id: "rate_limited",
        developer_message: "Too many requests, retry in a minute",
        details: {}
      )
    end
  end
end
