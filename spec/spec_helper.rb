# frozen_string_literal: true

# +SimpleCov.start+ must be invoked before any application code is loaded
require "simplecov"
SimpleCov.start do
  formatter SimpleCov::Formatter::SimpleFormatter
end

require_relative "../lib/datadog/ci"

require_relative "support/configuration_helpers"
require_relative "support/log_helpers"
require_relative "support/tracer_helpers"
require_relative "support/span_helpers"
require_relative "support/platform_helpers"
require_relative "support/git_helpers"
require_relative "support/provider_test_helpers"
require_relative "support/ci_mode_helpers"
require_relative "support/test_visibility_event_serialized"

require "rspec/collection_matchers"
require "climate_control"

if defined?(Warning.ignore)
  # Caused by https://github.com/cucumber/cucumber-ruby/blob/47c8e2d7c97beae8541c895a43f9ccb96324f0f1/lib/cucumber/encoding.rb#L5-L6
  Gem.path.each do |path|
    Warning.ignore(/setting Encoding.default_external/, path)
    Warning.ignore(/setting Encoding.default_internal/, path)
  end
end

RSpec.configure do |config|
  config.include ConfigurationHelpers
  config.include TracerHelpers
  config.include SpanHelpers

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Raise error when patching an integration fails.
  # This can be disabled by unstubbing +CommonMethods#on_patch_error+
  require "datadog/tracing/contrib/patcher"
  config.before do
    allow_any_instance_of(Datadog::Tracing::Contrib::Patcher::CommonMethods).to(receive(:on_patch_error)) { |_, e| raise e }
  end

  # Ensure tracer environment is clean before running tests.
  #
  # This is done :before and not :after because doing so after
  # can create noise for test assertions. For example:
  # +expect(Datadog).to receive(:shutdown!).once+
  config.before do
    Datadog.shutdown!
    # without_warnings { Datadog.configuration.reset! }
    Datadog.configuration.reset!
  end
end
