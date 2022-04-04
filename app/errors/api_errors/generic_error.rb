module ApiErrors
  class GenericError < ApiError
    def initialize(details = {})
      @http_code          = 500 #Internal server error
      @id                 = 'generic'
      @developer_message  = 'Generic, no handled runtime error. Contact with the backend team'
      details             = details.is_a?(Hash) ? details : { message: details }

      unless Rails.env.development? || Rails.env.test? || Rails.env.pre_production?
        details = { error_id: details.fetch(:error_id) }
      end

      @details = details
    end
  end
end
