# frozen_string_literal: true

require_relative "../../recorder"
require_relative "../../ext/test"
require_relative "ext"

module Datadog
  module CI
    module Contrib
      module RSpec
        # Instrument RSpec::Core::Example
        module Example
          def self.included(base)
            base.prepend(InstanceMethods)
          end

          # Instance methods for configuration
          module InstanceMethods
            def run(example_group_instance, reporter)
              return super unless configuration[:enabled]

              test_name = full_description.strip
              if metadata[:description].empty?
                # for unnamed it blocks this appends something like "example at ./spec/some_spec.rb:10"
                test_name += " #{description}"
              end

              CI.trace_test(
                test_name,
                metadata[:example_group][:file_path],
                configuration[:service_name],
                configuration[:operation_name],
                {
                  framework: Ext::FRAMEWORK,
                  framework_version: CI::Contrib::RSpec::Integration.version.to_s,
                  test_type: Ext::TEST_TYPE
                }
              ) do |test_span|
                result = super

                case execution_result.status
                when :passed
                  test_span.passed!
                when :failed
                  test_span.failed!(execution_result.exception)
                else
                  test_span.skipped!(execution_result.exception) if execution_result.example_skipped?
                end

                result
              end
            end

            private

            def configuration
              Datadog.configuration.ci[:rspec]
            end
          end
        end
      end
    end
  end
end
