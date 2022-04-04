class ApplicationController < ActionController::API
  rescue_from StandardError, with: :standard_error_handler

  private

  def standard_error_handler(err)
    err = ApiErrors::ApiError.from_rails_err(err) unless err.is_a?(ApiErrors::ApiError)

    render_api_error(err)
  end

  def render_api_error(api_err)
    render json: { error: api_err }, status: api_err.http_code
  end
end

