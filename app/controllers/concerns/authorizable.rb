# Exige l'en-tête X-Api-Key uniquement si API_KEY est défini côté serveur.
module Authorizable
  extend ActiveSupport::Concern

  HEADER = "X-Api-Key"

  included do
    before_action :authorize_api_key!
  end

  private

  def authorize_api_key!
    expected = Rails.configuration.x.api_key
    return if expected.blank?
    # Comparaison en temps constant : la durée ne révèle pas le préfixe correct.
    return if ActiveSupport::SecurityUtils.secure_compare(request.headers[HEADER].to_s, expected)

    raise ApiErrors::UnauthorizedError
  end
end
