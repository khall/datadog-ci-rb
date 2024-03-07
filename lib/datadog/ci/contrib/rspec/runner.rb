# frozen_string_literal: true

require_relative "../../ext/test"
require_relative "ext"

module Datadog
  module CI
    module Contrib
      module RSpec
        # Instrument RSpec::Core::Runner
        module Runner
          def self.included(base)
            base.prepend(InstanceMethods)
          end

          module InstanceMethods
            def run_specs(*)
              return super unless datadog_configuration[:enabled]

              test_session = CI.start_test_session(
                tags: {
                  CI::Ext::Test::TAG_FRAMEWORK => Ext::FRAMEWORK,
                  CI::Ext::Test::TAG_FRAMEWORK_VERSION => CI::Contrib::RSpec::Integration.version.to_s
                },
                service: datadog_configuration[:service_name]
              )

              test_module = CI.start_test_module(Ext::FRAMEWORK)

              result = super
              return result unless test_module && test_session

              if result != 0
                test_module.failed!
                test_session.failed!
              else
                test_module.passed!
                test_session.passed!
              end
              test_module.finish
              test_session.finish

              result
            end

            private

            def datadog_configuration
              Datadog.configuration.ci[:rspec]
            end
          end
        end
      end
    end
  end
end
