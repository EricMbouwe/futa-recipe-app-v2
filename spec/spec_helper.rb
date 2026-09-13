require "simplecov"

SimpleCov.start "rails" do
  enable_coverage :branch
  skip %w[ /spec/ /config/ /db/ ]
  # Seuil appliqué à la suite complète en CI ; une exécution ciblée (make test ARGS=…) ne l'impose pas.
  minimum_coverage line: 95, branch: 85 if ENV["CI"] == "true"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
