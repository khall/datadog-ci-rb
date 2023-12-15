# frozen_string_literal: true

require "weakref"

require_relative "../../ext/test"
require_relative "ext"

module Datadog
  module CI
    module Contrib
      module Minitest
        module Plugin
          def self.included(base)
            base.extend(ClassMethods)
          end

          module ClassMethods
            def plugin_datadog_ci_init(*)
              return unless datadog_configuration[:enabled]

              test_session = CI.start_test_session(
                tags: {
                  CI::Ext::Test::TAG_FRAMEWORK => Ext::FRAMEWORK,
                  CI::Ext::Test::TAG_FRAMEWORK_VERSION => CI::Contrib::Minitest::Integration.version.to_s,
                  CI::Ext::Test::TAG_TYPE => CI::Ext::Test::TEST_TYPE
                },
                service: datadog_configuration[:service_name]
              )
              CI.start_test_module(test_session.name)

              # we create dynamic class here to avoid referencing ::Minitest constant
              # in datadog-ci class definitions because Minitest is not always available
              datadog_reporter_klass = Class.new(::Minitest::AbstractReporter) do
                def initialize(reporter)
                  # This creates circular reference as reporter holds reference to this reporter.
                  # To make sure that reporter can be garbage collected, we use WeakRef.
                  @reporter = WeakRef.new(reporter)
                end

                def report
                  active_test_session = CI.active_test_session
                  active_test_module = CI.active_test_module

                  return unless @reporter.weakref_alive?
                  return if active_test_session.nil? || active_test_module.nil?

                  if @reporter.passed?
                    active_test_module.passed!
                    active_test_session.passed!
                  else
                    active_test_module.failed!
                    active_test_session.failed!
                  end

                  active_test_module.finish
                  active_test_session.finish
                end
              end

              reporter.reporters << datadog_reporter_klass.new(reporter)
            end

            private

            def datadog_configuration
              Datadog.configuration.ci[:minitest]
            end
          end
        end
      end
    end
  end
end
