module ApiErrors
  # Erreur métier sérialisée telle quelle dans { "error": … }.
  class ApiError < StandardError
    attr_reader :http_code, :id, :developer_message, :details

    def initialize(http_code:, id:, developer_message:, details: {})
      @http_code = http_code
      @id = id
      @developer_message = developer_message
      @details = details
      super(developer_message)
    end

    def as_json(*)
      { http_code:, id:, developer_message:, details: }
    end
  end
end
