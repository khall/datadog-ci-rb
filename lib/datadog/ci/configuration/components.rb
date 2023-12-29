# frozen_string_literal: true

require "datadog/core/configuration/agent_settings_resolver"
require "datadog/core/remote/negotiation"

require_relative "../ext/transport"
require_relative "../ext/settings"
require_relative "../test_visibility/flush"
require_relative "../test_visibility/recorder"
require_relative "../test_visibility/null_recorder"
require_relative "../test_visibility/serializers/factories/test_level"
require_relative "../test_visibility/serializers/factories/test_suite_level"
require_relative "../test_visibility/transport"
require_relative "../transport/api/builder"

module Datadog
  module CI
    module Configuration
      # Adds CI behavior to Datadog trace components
      module Components
        attr_reader :ci_recorder

        def initialize(settings)
          # Activate CI mode if enabled
          if settings.ci.enabled
            activate_ci!(settings)
          else
            @ci_recorder = TestVisibility::NullRecorder.new
          end

          super
        end

        def activate_ci!(settings)
          test_visibility_transport = nil
          agent_settings = Datadog::Core::Configuration::AgentSettingsResolver.call(settings)

          if settings.ci.agentless_mode_enabled
            check_dd_site(settings)
            test_visibility_transport = build_agentless_transport(settings)
          elsif can_use_evp_proxy?(settings, agent_settings)
            test_visibility_transport = build_evp_proxy_transport(settings, agent_settings)
          else
            settings.ci.experimental_test_suite_level_visibility_enabled = false
          end

          # Deactivate telemetry
          settings.telemetry.enabled = false

          # Deactivate remote configuration
          settings.remote.enabled = false

          # do not use 128-bit trace ids for CI visibility
          # they are used for OTEL compatibility in Datadog tracer
          settings.tracing.trace_id_128_bit_generation_enabled = false

          # Activate underlying tracing test mode
          settings.tracing.test_mode.enabled = true

          # Choose user defined TraceFlush or default to CI TraceFlush
          settings.tracing.test_mode.trace_flush = settings.ci.trace_flush || CI::TestVisibility::Flush::Partial.new

          writer_options = settings.ci.writer_options
          if test_visibility_transport
            writer_options[:transport] = test_visibility_transport
            writer_options[:shutdown_timeout] = 60
            writer_options[:buffer_size] = 10_000

            settings.tracing.test_mode.async = true
          end

          settings.tracing.test_mode.writer_options = writer_options

          @ci_recorder = TestVisibility::Recorder.new(
            test_suite_level_visibility_enabled: settings.ci.experimental_test_suite_level_visibility_enabled
          )
        end

        def can_use_evp_proxy?(settings, agent_settings)
          Datadog::Core::Remote::Negotiation.new(settings, agent_settings).endpoint?(
            Ext::Transport::EVP_PROXY_PATH_PREFIX
          )
        end

        def build_agentless_transport(settings)
          if settings.api_key.nil?
            # agentless mode is requested but no API key is provided -
            # we cannot continue and log an error
            # Tests are running without CI visibility enabled

            Datadog.logger.error(
              "DATADOG CONFIGURATION - CI VISIBILITY - ATTENTION - " \
              "Agentless mode was enabled but DD_API_KEY is not set: CI visibility is disabled. " \
              "Please make sure to set valid api key in DD_API_KEY environment variable"
            )

            settings.ci.enabled = false

            nil
          else
            Datadog.logger.debug("CI visibility configured to use agentless transport")

            Datadog::CI::TestVisibility::Transport.new(
              api: Transport::Api::Builder.build_ci_test_cycle_api(settings),
              serializers_factory: serializers_factory(settings),
              dd_env: settings.env
            )
          end
        end

        def build_evp_proxy_transport(settings, agent_settings)
          Datadog.logger.debug("CI visibility configured to use agent transport via EVP proxy")

          Datadog::CI::TestVisibility::Transport.new(
            api: Transport::Api::Builder.build_evp_proxy_api(agent_settings),
            serializers_factory: serializers_factory(settings),
            dd_env: settings.env
          )
        end

        def serializers_factory(settings)
          if settings.ci.experimental_test_suite_level_visibility_enabled
            Datadog::CI::TestVisibility::Serializers::Factories::TestSuiteLevel
          else
            Datadog::CI::TestVisibility::Serializers::Factories::TestLevel
          end
        end

        def check_dd_site(settings)
          return if settings.site.nil?
          return if Ext::Settings::DD_SITE_ALLOWLIST.include?(settings.site)

          Datadog.logger.warn(
            "CI VISIBILITY CONFIGURATION " \
            "Agentless mode was enabled but DD_SITE is not set to one of the following: #{Ext::Settings::DD_SITE_ALLOWLIST.join(", ")}. " \
            "Please make sure to set valid site in DD_SITE environment variable"
          )
        end
      end
    end
  end
end
