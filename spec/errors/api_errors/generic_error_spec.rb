require "rails_helper"

RSpec.describe ApiErrors::GenericError do
  let(:exception) do
    RuntimeError.new("boom").tap { |error| error.set_backtrace([ "#{Rails.root}/app/models/recipe.rb:1" ]) }
  end

  it "ne lève rien sans exception d'origine (régression API-02)" do
    expect { described_class.new(expose_internals: false) }.not_to raise_error
  end

  it "n'expose que l'error_id quand expose_internals est faux" do
    error = described_class.new(exception:, expose_internals: false)

    expect(error.details.keys).to eq([ :error_id ])
    expect(error.error_id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  it "expose l'exception nettoyée quand expose_internals est vrai" do
    error = described_class.new(exception:, expose_internals: true)

    expect(error.details).to include(error_id: error.error_id, exception: "RuntimeError", message: "boom")
    expect(error.details[:app_traces]).to eq([ "app/models/recipe.rb:1" ])
  end
end
