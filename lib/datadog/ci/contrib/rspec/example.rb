# frozen_string_literal: true

require_relative "../../ext/test"
require_relative "../../utils/git"
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

          module InstanceMethods
            def run(*)
              return super unless datadog_configuration[:enabled]

              test_name = full_description.strip
              if metadata[:description].empty?
                # for unnamed it blocks this appends something like "example at ./spec/some_spec.rb:10"
                test_name += " #{description}"
              end

              test_suite_description = fetch_top_level_example_group[:description]
              suite_name = "#{test_suite_description} at #{metadata[:example_group][:rerun_file_path]}"

              # remove suite name from test name to avoid duplication
              test_name = test_name.sub(test_suite_description, "").strip

              CI.trace_test(
                test_name,
                suite_name,
                tags: {
                  CI::Ext::Test::TAG_FRAMEWORK => Ext::FRAMEWORK,
                  CI::Ext::Test::TAG_FRAMEWORK_VERSION => CI::Contrib::RSpec::Integration.version.to_s,
                  CI::Ext::Test::TAG_SOURCE_FILE => Utils::Git.relative_to_root(metadata[:file_path]),
                  CI::Ext::Test::TAG_SOURCE_START => metadata[:line_number].to_s
                },
                service: datadog_configuration[:service_name]
              ) do |test_span|
                test_span.set_parameters({}, {"scoped_id" => metadata[:scoped_id]})

                result = super

                case execution_result.status
                when :passed
                  test_span.passed!
                when :failed
                  test_span.failed!(exception: execution_result.exception)
                else
                  test_span.skipped!(exception: execution_result.exception) if execution_result.example_skipped?
                end

                result
              end
            end

            private

            def fetch_top_level_example_group
              return metadata[:example_group] unless metadata[:example_group][:parent_example_group]

              res = metadata[:example_group][:parent_example_group]
              while (parent = res[:parent_example_group])
                res = parent
              end
              res
            end

            def datadog_configuration
              Datadog.configuration.ci[:rspec]
            end
          end
        end
      end
    end
  end
end
