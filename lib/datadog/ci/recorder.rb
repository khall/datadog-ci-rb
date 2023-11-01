# frozen_string_literal: true

require "datadog/tracing"
require "datadog/tracing/contrib/analytics"

require_relative "ext/app_types"
require_relative "ext/test"
require_relative "ext/environment"

require "rbconfig"

module Datadog
  module CI
    # Common behavior for CI tests
    module Recorder
      # Creates a new span for a CI test
      def self.trace_test(test_name, service_name: nil, operation_name: nil, tags: {})
        span_options = {
          resource: test_name,
          service: service_name,
          span_type: Ext::AppTypes::TYPE_TEST
        }

        tags[:test_name] = test_name

        if block_given?
          ::Datadog::Tracing.trace(operation_name, **span_options) do |span, trace|
            set_tags!(trace, span, tags)
            yield(Test.new(span))
          end
        else
          span = ::Datadog::Tracing.trace(operation_name, **span_options)
          trace = ::Datadog::Tracing.active_trace
          set_tags!(trace, span, tags)
          Test.new(span)
        end
      end

      def self.trace(span_type, span_name)
        span_options = {
          resource: span_name,
          span_type: span_type
        }

        if block_given?
          ::Datadog::Tracing.trace(span_name, **span_options) do |tracer_span|
            yield Span.new(tracer_span)
          end
        else
          tracer_span = Datadog::Tracing.trace(span_name, **span_options)
          Span.new(tracer_span)
        end
      end

      # Adds tags to a CI test span.
      def self.set_tags!(trace, span, tags = {})
        tags ||= {}

        # Set default tags
        trace.origin = Ext::Test::CONTEXT_ORIGIN if trace
        ::Datadog::Tracing::Contrib::Analytics.set_measured(span)
        span.set_tag(Ext::Test::TAG_SPAN_KIND, Ext::AppTypes::TYPE_TEST)

        # Set environment tags
        @environment_tags ||= Ext::Environment.tags(ENV)
        @environment_tags.each { |k, v| span.set_tag(k, v) }

        # Set contextual tags
        span.set_tag(Ext::Test::TAG_FRAMEWORK, tags[:framework]) if tags[:framework]
        span.set_tag(Ext::Test::TAG_FRAMEWORK_VERSION, tags[:framework_version]) if tags[:framework_version]
        span.set_tag(Ext::Test::TAG_NAME, tags[:test_name]) if tags[:test_name]
        span.set_tag(Ext::Test::TAG_SUITE, tags[:test_suite]) if tags[:test_suite]
        span.set_tag(Ext::Test::TAG_TYPE, tags[:test_type]) if tags[:test_type]

        set_environment_runtime_tags!(span)

        span
      end

      private_class_method def self.set_environment_runtime_tags!(span)
        span.set_tag(Ext::Test::TAG_OS_ARCHITECTURE, ::RbConfig::CONFIG["host_cpu"])
        span.set_tag(Ext::Test::TAG_OS_PLATFORM, ::RbConfig::CONFIG["host_os"])
        span.set_tag(Ext::Test::TAG_RUNTIME_NAME, Core::Environment::Ext::LANG_ENGINE)
        span.set_tag(Ext::Test::TAG_RUNTIME_VERSION, Core::Environment::Ext::ENGINE_VERSION)
      end
    end
  end
end
