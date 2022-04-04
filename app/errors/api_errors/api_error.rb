module ApiErrors
  class ApiError < StandardError
    attr_reader(
      :http_code,
      :id,
      :developer_message,
      :details
    )

    def self.from_rails_err(err)
      if err.is_a?(ActiveRecord::RecordNotFound)
        return ApiErrors::ResourceNotFoundError.new(err.message)
      end

      details = {
        exception: err.class.to_s,
        message: err.message,
        app_traces: Rails.backtrace_cleaner.clean(err.backtrace),
      }

      ApiErrors::GenericError.new(details)
    end

    def as_json(*)
      {
        http_code: @http_code,
        id: @id,
        developer_message: @developer_message,
        details: @details
      }
    end
  end
end
