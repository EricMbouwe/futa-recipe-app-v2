class ApplicationController < ActionController::API
  # En production, une exception imprévue devient un 500 JSON journalisé.
  # En développement et en test, elle remonte pour être vue là où elle naît.
  class_attribute :render_unexpected_errors, default: Rails.env.production?

  # rescue_from teste les gestionnaires du dernier déclaré au premier.
  rescue_from StandardError, with: :handle_unexpected_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from ApiErrors::ApiError, with: :render_api_error

  private

  def handle_unexpected_error(exception)
    raise exception unless render_unexpected_errors

    error = ApiErrors::GenericError.new(exception:)
    Rails.logger.error(
      {
        error_id: error.error_id,
        exception: exception.class.name,
        message: exception.message,
        backtrace: Array(exception.backtrace).first(20)
      }.to_json
    )
    render_api_error(error)
  end

  def handle_record_not_found(exception)
    render_api_error(ApiErrors::ResourceNotFoundError.new(exception.message))
  end

  def render_api_error(error)
    render json: { error: }, status: error.http_code
  end
end
