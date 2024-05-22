require "time"

RSpec.describe "RSpec hooks" do
  # Yields to a block in a new RSpec global context. All RSpec
  # test configuration and execution should be wrapped in this method.
  def with_new_rspec_environment
    old_configuration = ::RSpec.configuration
    old_world = ::RSpec.world
    ::RSpec.configuration = ::RSpec::Core::Configuration.new
    ::RSpec.world = ::RSpec::Core::World.new

    yield
  ensure
    ::RSpec.configuration = old_configuration
    ::RSpec.world = old_world
  end

  def devnull
    File.new("/dev/null", "w")
  end

  def rspec_session_run(
    with_failed_test: false,
    with_shared_test: false,
    with_shared_context: false,
    unskippable: {
      test: false,
      context: false,
      suite: false
    },
    dry_run: false
  )
    test_meta = unskippable[:test] ? {Datadog::CI::Ext::Test::ITR_UNSKIPPABLE_OPTION => true} : {}
    context_meta = unskippable[:context] ? {Datadog::CI::Ext::Test::ITR_UNSKIPPABLE_OPTION => true} : {}
    suite_meta = unskippable[:suite] ? {Datadog::CI::Ext::Test::ITR_UNSKIPPABLE_OPTION => true} : {}
    with_new_rspec_environment do
      spec = RSpec.describe "SomeTest", suite_meta do
        context "nested", context_meta do
          it "foo", test_meta do
            expect(1 + 1).to eq(2)
          end

          if with_failed_test
            it "fails" do
              expect(1).to eq(2)
            end
          end

          if with_shared_test
            require_relative "some_shared_examples"
            include_examples "Testing shared examples", 2
            include_examples "Testing shared examples", 1
          end

          if with_shared_context
            require_relative "some_shared_context"
            include_context "Shared context"
          end
        end
      end

      options_array = %w[--pattern none]
      if dry_run
        options_array << "--dry-run"
      end
      options = ::RSpec::Core::ConfigurationOptions.new(options_array)
      ::RSpec::Core::Runner.new(options).run(devnull, devnull)

      spec
    end
  end

  context "running individual tests" do
    include_context "CI mode activated" do
      let(:integration_name) { :rspec }
      let(:integration_options) { {service_name: "lspec"} }
    end

    it "creates span for example" do
      spec = with_new_rspec_environment do
        RSpec.describe "some test" do
          it "foo" do
            # DO NOTHING
          end
        end.tap(&:run)
      end

      expect(first_test_span.type).to eq(Datadog::CI::Ext::AppTypes::TYPE_TEST)
      expect(first_test_span.service).to eq("lspec")

      expect(first_test_span.name).to eq("foo")
      expect(first_test_span.resource).to eq("foo")

      expect(first_test_span).to have_test_tag(:name, "foo")
      expect(first_test_span).to have_test_tag(:suite, "some test at #{spec.file_path}")

      expect(first_test_span).to have_test_tag(:span_kind, "test")
      expect(first_test_span).to have_test_tag(:type, "test")

      expect(first_test_span).to have_test_tag(:framework, "rspec")
      expect(first_test_span).to have_test_tag(
        :framework_version,
        Datadog::CI::Contrib::RSpec::Integration.version.to_s
      )

      expect(first_test_span).to have_pass_status

      expect(first_test_span).to have_test_tag(
        :source_file,
        "spec/datadog/ci/contrib/rspec/instrumentation_spec.rb"
      )
      expect(first_test_span).to have_test_tag(:source_start, "82")
      expect(first_test_span).to have_test_tag(
        :codeowners,
        "[\"@DataDog/ruby-guild\", \"@DataDog/ci-app-libraries\"]"
      )
    end

    it "creates spans for several examples" do
      expect(Datadog::CI::Ext::Environment).to receive(:tags).never

      num_examples = 20
      with_new_rspec_environment do
        RSpec.describe "many tests" do
          num_examples.times do |n|
            it n do
              # DO NOTHING
            end
          end
        end.run
      end

      expect(test_spans).to have(num_examples).items
    end

    it "creates span for unnamed examples" do
      with_new_rspec_environment do
        RSpec.describe "some unnamed test" do
          it {}
        end.run
      end

      expect(first_test_span).to have_test_tag(:name, /example at .+/)
    end

    it "creates span for deeply nested examples" do
      spec = with_new_rspec_environment do
        RSpec.describe "some nested test" do
          context "1" do
            context "2" do
              context "3" do
                context "4" do
                  context "5" do
                    context "6" do
                      context "7" do
                        context "8" do
                          context "9" do
                            context "10" do
                              it "foo" do
                                # DO NOTHING
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end.tap(&:run)
      end

      expect(first_test_span.resource).to eq("1 2 3 4 5 6 7 8 9 10 foo")
      expect(first_test_span).to have_test_tag(:name, "1 2 3 4 5 6 7 8 9 10 foo")
      expect(first_test_span).to have_test_tag(:suite, "some nested test at #{spec.file_path}")
    end

    it "creates spans for example with instrumentation" do
      with_new_rspec_environment do
        RSpec.describe "some test" do
          it "foo" do
            Datadog::Tracing.trace("get_time") do
              Time.now
            end
          end
        end.tap(&:run)
      end

      expect(test_spans).to have(1).items
      expect(custom_spans).to have(1).items
      expect(custom_spans).to all have_origin(Datadog::CI::Ext::Test::CONTEXT_ORIGIN)
    end

    context "catches failures" do
      def expect_failure
        expect(first_test_span).to have_fail_status
        expect(first_test_span).to have_error
        expect(first_test_span).to have_error_type
        expect(first_test_span).to have_error_message
        expect(first_test_span).to have_error_stack
      end

      it "within let" do
        with_new_rspec_environment do
          RSpec.describe "some failed test with let" do
            let(:let_failure) { raise "failure" }

            it "foo" do
              let_failure
            end
          end.run
        end

        expect_failure
      end

      it "within around" do
        with_new_rspec_environment do
          RSpec.describe "some failed test with around" do
            around do |example|
              example.run
              raise "failure"
            end

            it "foo" do
              # DO NOTHING
            end
          end.run
        end

        expect_failure
      end

      it "within before" do
        with_new_rspec_environment do
          RSpec.describe "some failed test with before" do
            before do
              raise "failure"
            end

            it "foo" do
              # DO NOTHING
            end
          end.run
        end

        expect_failure
      end

      it "within after" do
        with_new_rspec_environment do
          RSpec.describe "some failed test with after" do
            after do
              raise "failure"
            end

            it "foo" do
              # DO NOTHING
            end
          end.run
        end

        expect_failure
      end
    end

    context "supports skipped examples" do
      it "with skip: true" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo", skip: true do
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "No reason given")
        expect(first_test_span).not_to have_error
      end

      it "with skip: reason" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo", skip: "reason in it block" do
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "reason in it block")
        expect(first_test_span).not_to have_error
      end

      it "with skip instead of it" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            skip "foo" do
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "No reason given")
        expect(first_test_span).not_to have_error
      end

      it "with xit" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            xit "foo" do
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "Temporarily skipped with xit")
        expect(first_test_span).not_to have_error
      end

      it "with skip call" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo" do
              skip
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "No reason given")
        expect(first_test_span).not_to have_error
      end

      it "with skip call and reason given" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo" do
              skip("reason")
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "reason")
        expect(first_test_span).not_to have_error
      end

      it "with empty body" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo"
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "Not yet implemented")
        expect(first_test_span).not_to have_error
      end

      it "with xcontext" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            xcontext "foo" do
              it "bar" do
                expect(1 + 1).to eq(5)
              end
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo bar")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "Temporarily skipped with xcontext")
        expect(first_test_span).not_to have_error
      end

      it "with pending keyword and failure" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo", pending: "did not fix the math yet" do
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "did not fix the math yet")
        expect(first_test_span).to have_error
      end

      it "with pending keyword and passing" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo", pending: "did not fix the math yet" do
              expect(1 + 1).to eq(2)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_fail_status
        expect(first_test_span).to have_error
        expect(first_test_span).to have_error_message("Expected example to fail since it is pending, but it passed.")
      end

      it "with pending method, reason and failure" do
        with_new_rspec_environment do
          RSpec.describe "some skipped test" do
            it "foo" do
              pending("did not fix the math yet")
              expect(1 + 1).to eq(5)
            end
          end.run
        end

        expect(first_test_span).to have_test_tag(:name, "foo")

        expect(first_test_span).to have_skip_status
        expect(first_test_span).to have_test_tag(:skip_reason, "did not fix the math yet")
        expect(first_test_span).to have_error
      end
    end

    context "with git root changed" do
      before do
        expect(Datadog::CI::Git::LocalRepository).to receive(:root).and_return("#{Dir.pwd}/spec")
      end

      it "provides source file path relative to git root" do
        with_new_rspec_environment do
          RSpec.describe "some test" do
            it "foo" do
              # DO NOTHING
            end
          end.tap(&:run)
        end

        expect(first_test_span).to have_test_tag(
          :source_file,
          "datadog/ci/contrib/rspec/instrumentation_spec.rb"
        )
      end
    end
  end

  context "with rspec runner" do
    include_context "CI mode activated" do
      let(:integration_name) { :rspec }
      let(:integration_options) { {service_name: "lspec"} }
    end

    it "creates test session span" do
      rspec_session_run

      expect(test_session_span).not_to be_nil

      expect(test_session_span.type).to eq("test_session_end")

      expect(test_session_span).to have_test_tag(:span_kind, "test")
      expect(test_session_span).to have_test_tag(:framework, "rspec")
      expect(test_session_span).to have_test_tag(
        :framework_version,
        Datadog::CI::Contrib::RSpec::Integration.version.to_s
      )

      expect(test_session_span).not_to have_test_tag(:code_coverage_enabled)

      # ITR
      expect(test_session_span).not_to have_test_tag(:itr_test_skipping_enabled)
      expect(test_session_span).not_to have_test_tag(:itr_test_skipping_type)
      expect(test_session_span).not_to have_test_tag(:itr_tests_skipped)
      expect(test_session_span).not_to have_test_tag(:itr_test_skipping_count)

      expect(test_session_span).to have_pass_status
    end

    it "creates test module span" do
      rspec_session_run

      expect(test_module_span).not_to be_nil

      expect(test_module_span.type).to eq("test_module_end")
      expect(test_module_span.name).to eq("rspec")

      expect(test_module_span).to have_test_tag(:span_kind, "test")
      expect(test_module_span).to have_test_tag(:framework, "rspec")
      expect(test_module_span).to have_test_tag(
        :framework_version,
        Datadog::CI::Contrib::RSpec::Integration.version.to_s
      )
      expect(test_module_span).to have_pass_status
    end

    it "creates test suite span" do
      spec = rspec_session_run

      expect(first_test_suite_span).not_to be_nil

      expect(first_test_suite_span.type).to eq("test_suite_end")
      expect(first_test_suite_span.name).to eq("SomeTest at #{spec.file_path}")

      expect(first_test_suite_span).to have_test_tag(:span_kind, "test")
      expect(first_test_suite_span).to have_test_tag(:framework, "rspec")
      expect(first_test_suite_span).to have_test_tag(
        :framework_version,
        Datadog::CI::Contrib::RSpec::Integration.version.to_s
      )
      expect(first_test_suite_span).to have_pass_status
    end

    it "connects test to the session, module, and suite" do
      rspec_session_run

      expect(first_test_span).to have_test_tag(:test_session_id, test_session_span.id.to_s)
      expect(first_test_span).to have_test_tag(:test_module_id, test_module_span.id.to_s)
      expect(first_test_span).to have_test_tag(:test_suite_id, first_test_suite_span.id.to_s)
    end

    context "with failures" do
      it "creates test session span with failed state" do
        rspec_session_run(with_failed_test: true)

        expect(test_session_span).to have_fail_status
      end

      it "creates test module span with failed state" do
        rspec_session_run(with_failed_test: true)

        expect(test_module_span).to have_fail_status
      end

      it "creates test suite span with failed state" do
        rspec_session_run(with_failed_test: true)

        expect(first_test_suite_span).to have_fail_status
      end
    end

    context "with shared examples" do
      let!(:spec) { rspec_session_run(with_shared_test: true) }

      it "creates correct test spans connects all tests to a single test suite" do
        shared_test_spans = test_spans.filter { |test_span| test_span.name == "nested shared examples adds 1 and 1" }
        expect(shared_test_spans).to have(2).items

        shared_test_spans.each_with_index do |shared_test_span, index|
          expect(shared_test_span).to have_test_tag(:suite, "SomeTest at #{spec.file_path}")

          expect(shared_test_span).to have_test_tag(
            :parameters,
            "{\"arguments\":{},\"metadata\":{\"scoped_id\":\"1:1:#{2 + index}:1\"}}"
          )
        end

        expect(test_spans).to all have_test_tag(:test_suite_id, first_test_suite_span.id.to_s)
      end
    end

    context "with skipped test suite" do
      def rspec_skipped_session_run
        with_new_rspec_environment do
          RSpec.describe "SomeTest" do
            it "foo" do
              # DO NOTHING
            end
          end

          spec = RSpec.describe "SkippedTest" do
            context "nested" do
              it "skipped foo", skip: true do
                # DO NOTHING
              end

              it "pending fails" do
                pending("did not fix the math yet")
                expect(1).to eq(2)
              end
            end
          end

          options = ::RSpec::Core::ConfigurationOptions.new(%w[--pattern none])
          ::RSpec::Core::Runner.new(options).run(devnull, devnull)

          spec
        end
      end

      before do
        rspec_skipped_session_run
      end

      it "marks test session as passed" do
        expect(test_session_span).to have_pass_status
      end

      it "marks test suite as skipped" do
        skipped_suite = test_suite_spans.find do |suite_span|
          suite_span.get_tag(Datadog::CI::Ext::Test::TAG_SUITE).include?("SkippedTest")
        end

        expect(skipped_suite).to have_skip_status
      end
    end
  end

  context "with code coverage collected" do
    before { skip if PlatformHelpers.jruby? }

    before do
      allow(Datadog::CI::Git::LocalRepository).to receive(:root).and_return(__dir__)
    end

    include_context "CI mode activated" do
      let(:integration_name) { :rspec }
      let(:integration_options) { {service_name: "lspec"} }

      let(:itr_enabled) { true }
      let(:code_coverage_enabled) { true }
    end

    it "collects code coverage" do
      rspec_session_run(with_failed_test: true, with_shared_context: true)

      expect(test_session_span).not_to be_nil
      expect(test_session_span).to have_test_tag(:code_coverage_enabled, "true")
      expect(test_session_span).to have_test_tag(:itr_test_skipping_type, "test")
      expect(test_session_span).to have_test_tag(:itr_test_skipping_enabled, "false")

      expect(test_spans).to have(3).items

      expect(coverage_events).to have(3).items
      expect_coverage_events_belong_to_session(test_session_span)
      expect_coverage_events_belong_to_suite(first_test_suite_span)
      expect_coverage_events_belong_to_tests(test_spans)
      expect_non_empty_coverages

      # collects coverage from shared context files
      shared_context_test = test_spans.find { |span| span.name == "nested is 42" }
      shared_context_coverage = find_coverage_for_test(shared_context_test)

      expect(shared_context_coverage.coverage).to eq({
        File.join(__dir__, "some_shared_context.rb") => true
      })
    end
  end

  context "when skipping tests" do
    include_context "CI mode activated" do
      let(:integration_name) { :rspec }
      let(:integration_options) { {service_name: "lspec"} }

      let(:itr_enabled) { true }
      let(:tests_skipping_enabled) { true }
    end

    context "skipped a single test" do
      let(:itr_skippable_tests) do
        Set.new([
          'SomeTest at ./spec/datadog/ci/contrib/rspec/instrumentation_spec.rb.nested foo.{"arguments":{},"metadata":{"scoped_id":"1:1:1"}}'
        ])
      end

      it "skips test" do
        rspec_session_run(with_failed_test: true)

        expect(test_spans).to have(2).items
        expect(test_spans).to have_tag_values_no_order(:status, ["skip", "fail"])

        itr_skipped_test = test_spans.find { |span| span.name == "nested foo" }
        expect(itr_skipped_test).to have_test_tag(:itr_skipped_by_itr, "true")
      end

      it "sends test session level tags" do
        rspec_session_run(with_failed_test: true)

        expect(test_session_span).to have_test_tag(:itr_test_skipping_enabled, "true")
        expect(test_session_span).to have_test_tag(:itr_test_skipping_type, "test")
        expect(test_session_span).to have_test_tag(:itr_tests_skipped, "true")
        expect(test_session_span).to have_test_tag(:itr_test_skipping_count, 1)
      end
    end

    context "skipped all tests" do
      let(:itr_skippable_tests) do
        Set.new([
          'SomeTest at ./spec/datadog/ci/contrib/rspec/instrumentation_spec.rb.nested foo.{"arguments":{},"metadata":{"scoped_id":"1:1:1"}}',
          'SomeTest at ./spec/datadog/ci/contrib/rspec/instrumentation_spec.rb.nested fails.{"arguments":{},"metadata":{"scoped_id":"1:1:2"}}'
        ])
      end

      it "skips tests and suite" do
        rspec_session_run(with_failed_test: true)

        expect(test_spans).to have(2).items
        expect(test_spans).to all have_skip_status
        expect(test_spans).to all have_test_tag(:itr_skipped_by_itr, "true")
        expect(first_test_suite_span).to have_skip_status
      end

      it "sends test session level tags" do
        rspec_session_run(with_failed_test: true)

        expect(test_session_span).to have_test_tag(:itr_tests_skipped, "true")
        expect(test_session_span).to have_test_tag(:itr_test_skipping_count, 2)
      end

      context "but some tests are unskippable" do
        context "when a test is unskippable" do
          it "runs the test and adds forced run tag" do
            rspec_session_run(with_failed_test: true, unskippable: {test: true})

            expect(test_spans).to have(2).items
            expect(test_spans).to have_tag_values_no_order(:status, ["skip", "pass"])

            itr_unskippable_test = test_spans.find { |span| span.name == "nested foo" }
            expect(itr_unskippable_test).not_to have_test_tag(:itr_skipped_by_itr)
            expect(itr_unskippable_test).to have_test_tag(:itr_forced_run, "true")

            itr_skipped_test = test_spans.find { |span| span.name == "nested fails" }
            expect(itr_skipped_test).to have_test_tag(:itr_skipped_by_itr, "true")

            expect(test_session_span).to have_test_tag(:itr_tests_skipped, "true")
            expect(test_session_span).to have_test_tag(:itr_test_skipping_count, 1)
          end
        end

        context "when a context is unskippable" do
          it "runs all tests in context and adds forced run tag" do
            rspec_session_run(with_failed_test: true, unskippable: {context: true})

            expect(test_spans).to have(2).items
            expect(test_spans).to have_tag_values_no_order(:status, ["fail", "pass"])
            expect(test_spans).to all have_test_tag(:itr_forced_run, "true")

            expect(test_session_span).to have_test_tag(:itr_tests_skipped, "false")
            expect(test_session_span).to have_test_tag(:itr_test_skipping_count, 0)
          end
        end

        context "when a suite is unskippable" do
          it "runs all tests in context and adds forced run tag" do
            rspec_session_run(with_failed_test: true, unskippable: {suite: true})

            expect(test_spans).to have(2).items
            expect(test_spans).to have_tag_values_no_order(:status, ["fail", "pass"])
            expect(test_spans).to all have_test_tag(:itr_forced_run, "true")

            expect(test_session_span).to have_test_tag(:itr_tests_skipped, "false")
            expect(test_session_span).to have_test_tag(:itr_test_skipping_count, 0)
          end
        end
      end
    end
  end

  context "with dry run" do
    include_context "CI mode activated" do
      let(:integration_name) { :rspec }
      let(:integration_options) { {service_name: "lspec"} }
    end

    it "does not instrument test session" do
      rspec_session_run(dry_run: true)

      expect(test_session_span).to be_nil
      expect(test_spans).to be_empty
    end
  end
end
