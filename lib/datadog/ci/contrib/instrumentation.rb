# frozen_string_literal: true

module Datadog
  module CI
    module Contrib
      module Instrumentation
        class InvalidIntegrationError < StandardError; end

        @registry = {}

        def self.registry
          @registry
        end

        def self.register_integration(integration_class)
          @registry[integration_name(integration_class)] = integration_class.new
        end

        # Auto instrumentation of all integrations.
        #
        # Registers a :script_compiled tracepoint to watch for new Ruby files being loaded.
        # On every file load it checks if any of the integrations are patchable now.
        # Only the integrations that are available in the environment are checked.
        def self.auto_instrument
          Datadog.logger.debug("Auto instrumenting all integrations...")

          auto_instrumented_integrations = []
          @registry.each do |name, integration|
            # ignore integrations that are not in the Gemfile or have incompatible versions
            next unless integration.compatible?

            # late instrumented integrations will be patched when the test session starts
            next if integration.late_instrument?

            Datadog.logger.debug("#{name} should be auto instrumented")
            auto_instrumented_integrations << integration
          end

          if auto_instrumented_integrations.empty?
            Datadog.logger.warn(
              "Auto instrumentation was requested, but no available integrations were found. " \
              "Tests will be run without Datadog instrumentation."
            )
            return
          end

          script_compiled_tracepoint = TracePoint.new(:script_compiled) do
            auto_instrumented_integrations.each do |integration|
              next if integration.patched?
              next unless integration.loaded?

              Datadog.logger.debug("#{integration.class} is loaded")

              patch_integration(integration)
            end
          end
          script_compiled_tracepoint.enable
        end

        # Manual instrumentation of a specific integration.
        #
        # This method is called when user has `c.ci.instrument :integration_name` in their code.
        def self.instrument(integration_name, options = {}, &block)
          integration = fetch_integration(integration_name)
          # when manually instrumented, it might be configured via code
          integration.configure(options, &block)

          return unless integration.enabled

          patch_integration(integration, with_dependencies: true)
        end

        # This method instruments all additional test libraries (ex: selenium-webdriver) that need to be instrumented
        # later in the test suite run.
        #
        # It is intended to be called when test session starts to add additional capabilities to test visibility.
        #
        # This method does not automatically instrument test frameworks (ex: RSpec, Cucumber, etc), it requires
        # test framework to be already instrumented.
        def self.instrument_on_session_start
          Datadog.logger.debug("Instrumenting all late instrumented integrations...")

          @registry.each do |name, integration|
            next unless integration.late_instrument?
            next unless integration.enabled

            Datadog.logger.debug "#{name} is allowed to be late instrumented"

            patch_integration(integration)
          end
        end

        def self.fetch_integration(name)
          @registry[name] ||
            raise(InvalidIntegrationError, "'#{name}' is not a valid integration.")
        end

        # take the parent module name and downcase it
        # for example for Datadog::CI::Contrib::RSpec::Integration it will be :rspec
        def self.integration_name(subclass)
          result = subclass.name&.split("::")&.[](-2)&.downcase&.to_sym
          raise "Integration name could not be derived for #{subclass}" if result.nil?
          result
        end

        def self.patch_integration(integration, with_dependencies: false)
          patch_results = integration.patch

          if patch_results[:ok]
            Datadog.logger.debug("#{integration.class} is patched")

            return unless with_dependencies

            # try to patch dependant integrations (for example knapsack that depends on rspec)
            dependants = integration.dependants
              .map { |name| fetch_integration(name) }
              .filter { |integration| integration.patchable? }

            Datadog.logger.debug("Found dependent integrations for #{integration.class}: #{dependants}")

            dependants.each do |dependent_integration|
              patch_integration(dependent_integration, with_dependencies: true)
            end

          else
            Datadog.logger.debug("Attention: #{integration.class} is not patched (#{patch_results})")
          end
        end
      end
    end
  end
end
