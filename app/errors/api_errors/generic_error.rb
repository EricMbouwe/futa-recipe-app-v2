module ApiErrors
  # Erreur imprévue. Le client ne reçoit que l'error_id, qui permet de retrouver la trace dans les logs.
  class GenericError < ApiError
    attr_reader :error_id

    def initialize(exception: nil, error_id: SecureRandom.uuid, expose_internals: Rails.env.local?)
      @error_id = error_id
      details = { error_id: }

      if expose_internals && exception
        details.merge!(
          exception: exception.class.name,
          message: exception.message,
          app_traces: Rails.backtrace_cleaner.clean(exception.backtrace || [])
        )
      end

      super(
        http_code: 500,
        id: "generic",
        developer_message: "Unexpected server error. Quote the error_id when reporting it.",
        details:
      )
    end
  end
end
