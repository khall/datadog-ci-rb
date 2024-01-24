require "stringio"
require "fileutils"
require "cucumber"

RSpec.describe "Cucumber formatter" do
  extend ConfigurationHelpers

  include_context "CI mode activated" do
    let(:integration_name) { :cucumber }
    let(:integration_options) { {service_name: "jalapenos"} }
  end

  let(:cucumber_8_or_above) { Gem::Version.new("8.0.0") <= Datadog::CI::Contrib::Cucumber::Integration.version }
  let(:cucumber_4_or_above) { Gem::Version.new("4.0.0") <= Datadog::CI::Contrib::Cucumber::Integration.version }

  let(:run_id) { rand(1..2**64 - 1) }
  let(:steps_file_definition_path) { "spec/datadog/ci/contrib/cucumber/features/step_definitions/steps.rb" }
  let(:steps_file_for_run_path) do
    "spec/datadog/ci/contrib/cucumber/features/step_definitions/steps_#{run_id}.rb"
  end

  # Cucumber runtime setup
  let(:existing_runtime) { Cucumber::Runtime.new(runtime_options) }
  let(:runtime_options) { {} }
  # CLI configuration
  let(:feature_file_to_run) {}
  let(:features_path) { "spec/datadog/ci/contrib/cucumber/features/#{feature_file_to_run}" }
  let(:args) do
    [
      "-r",
      steps_file_for_run_path,
      features_path
    ]
  end
  let(:stdin) { StringIO.new }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:kernel) { double(:kernel) }

  let(:cli) do
    if cucumber_8_or_above
      Cucumber::Cli::Main.new(args, stdout, stderr, kernel)
    else
      Cucumber::Cli::Main.new(args, stdin, stdout, stderr, kernel)
    end
  end

  let(:expected_test_run_code) { 0 }

  before do
    # Ruby loads any file at most once per process, but we need to load
    # the cucumber step definitions multiple times for every Cucumber::Runtime we create
    # So we add a random number to the file path to force Ruby to load it again
    FileUtils.cp(
      steps_file_definition_path,
      steps_file_for_run_path
    )

    expect(Datadog::CI::Ext::Environment).to receive(:tags).never
    expect(kernel).to receive(:exit).with(expected_test_run_code)

    cli.execute!(existing_runtime)
  end

  after do
    FileUtils.rm(steps_file_for_run_path)
  end

  context "executing a passing test suite" do
    let(:feature_file_to_run) { "passing.feature" }

    it "creates spans for each scenario and step" do
      expect(test_spans).to have(4).items

      scenario_span = spans.find { |s| s.resource == "cucumber scenario" }

      expect(scenario_span.type).to eq(Datadog::CI::Ext::AppTypes::TYPE_TEST)
      expect(scenario_span.name).to eq("cucumber scenario")
      expect(scenario_span.resource).to eq("cucumber scenario")
      expect(scenario_span.service).to eq("jalapenos")

      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SPAN_KIND)).to eq(Datadog::CI::Ext::Test::SPAN_KIND_TEST)
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_NAME)).to eq("cucumber scenario")
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SUITE)).to eq(
        "Datadog integration at spec/datadog/ci/contrib/cucumber/features/passing.feature"
      )
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_TYPE)).to eq(Datadog::CI::Ext::Test::Type::TEST)
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK)).to eq(
        Datadog::CI::Contrib::Cucumber::Ext::FRAMEWORK
      )
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK_VERSION)).to eq(
        Datadog::CI::Contrib::Cucumber::Integration.version.to_s
      )
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::PASS)

      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SOURCE_FILE)).to eq(
        "spec/datadog/ci/contrib/cucumber/features/passing.feature"
      )
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SOURCE_START)).to eq("3")
      expect(scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_CODEOWNERS)).to eq(
        "[\"@DataDog/ruby-guild\", \"@DataDog/ci-app-libraries\"]"
      )

      step_span = spans.find { |s| s.resource == "datadog" }
      expect(step_span.resource).to eq("datadog")

      spans.each do |span|
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::Distributed::TAG_ORIGIN))
          .to eq(Datadog::CI::Ext::Test::CONTEXT_ORIGIN)
      end
    end

    it "marks undefined cucumber scenario as skipped" do
      undefined_scenario_span = spans.find { |s| s.resource == "undefined scenario" }
      expect(undefined_scenario_span).not_to be_nil
      expect(undefined_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::SKIP
      )
      expect(undefined_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SKIP_REASON)).to eq(
        'Undefined step: "undefined"'
      )
    end

    it "marks pending cucumber scenario as skipped" do
      pending_scenario_span = spans.find { |s| s.resource == "pending scenario" }
      expect(pending_scenario_span).not_to be_nil
      expect(pending_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::SKIP
      )
      expect(pending_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SKIP_REASON)).to eq(
        "implementation"
      )
    end

    it "marks skipped cucumber scenario as skipped" do
      skipped_scenario_span = spans.find { |s| s.resource == "skipped scenario" }
      expect(skipped_scenario_span).not_to be_nil
      expect(skipped_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::SKIP
      )
      expect(skipped_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_SKIP_REASON)).to eq(
        "Scenario skipped"
      )
    end

    it "creates test session span" do
      expect(test_session_span).not_to be_nil
      expect(test_session_span.service).to eq("jalapenos")
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_SPAN_KIND)).to eq(
        Datadog::CI::Ext::Test::SPAN_KIND_TEST
      )
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK)).to eq(
        Datadog::CI::Contrib::Cucumber::Ext::FRAMEWORK
      )
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK_VERSION)).to eq(
        Datadog::CI::Contrib::Cucumber::Integration.version.to_s
      )
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::PASS)
    end

    it "creates test module span" do
      expect(test_module_span).not_to be_nil
      expect(test_module_span.name).to eq(test_command)
      expect(test_module_span.service).to eq("jalapenos")
      expect(test_module_span.get_tag(Datadog::CI::Ext::Test::TAG_SPAN_KIND)).to eq(
        Datadog::CI::Ext::Test::SPAN_KIND_TEST
      )
      expect(test_module_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK)).to eq(
        Datadog::CI::Contrib::Cucumber::Ext::FRAMEWORK
      )
      expect(test_module_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK_VERSION)).to eq(
        Datadog::CI::Contrib::Cucumber::Integration.version.to_s
      )
      expect(test_module_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::PASS)
    end

    it "creates test suite span" do
      expect(test_suite_span).not_to be_nil
      expect(test_suite_span.name).to eq("Datadog integration at spec/datadog/ci/contrib/cucumber/features/passing.feature")
      expect(test_suite_span.service).to eq("jalapenos")
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_SPAN_KIND)).to eq(
        Datadog::CI::Ext::Test::SPAN_KIND_TEST
      )
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK)).to eq(
        Datadog::CI::Contrib::Cucumber::Ext::FRAMEWORK
      )
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK_VERSION)).to eq(
        Datadog::CI::Contrib::Cucumber::Integration.version.to_s
      )
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::PASS)
    end

    it "connects scenario span to test session and test module" do
      expect(first_test_span.get_tag(Datadog::CI::Ext::Test::TAG_TEST_MODULE_ID)).to eq(test_module_span.id.to_s)
      expect(first_test_span.get_tag(Datadog::CI::Ext::Test::TAG_MODULE)).to eq(test_command)
      expect(first_test_span.get_tag(Datadog::CI::Ext::Test::TAG_TEST_SESSION_ID)).to eq(test_session_span.id.to_s)
      expect(first_test_span.get_tag(Datadog::CI::Ext::Test::TAG_TEST_SUITE_ID)).to eq(test_suite_span.id.to_s)
      expect(first_test_span.get_tag(Datadog::CI::Ext::Test::TAG_SUITE)).to eq(test_suite_span.name)
    end
  end

  context "executing a failing test suite" do
    let(:feature_file_to_run) { "failing.feature" }
    let(:expected_test_run_code) { 2 }

    it "creates all CI spans with failed state" do
      expect(first_test_span.name).to eq("cucumber failing scenario")
      expect(first_test_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )

      step_span = spans.find { |s| s.resource == "failure" }
      expect(step_span.name).to eq("failure")
      expect(step_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )

      expect(test_suite_span.name).to eq(
        "Datadog integration - test failing features at spec/datadog/ci/contrib/cucumber/features/failing.feature"
      )
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )

      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
      expect(test_module_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
    end
  end

  context "executing a scenario with examples" do
    let(:feature_file_to_run) { "with_parameters.feature" }

    it "a single test suite, and a test span for each example with parameters JSON" do
      expect(test_spans).to have(3).items
      expect(test_suite_spans).to have(1).item

      test_spans.each_with_index do |span, index|
        # test parameters are available since cucumber 4
        if cucumber_4_or_above
          expect(span.get_tag(Datadog::CI::Ext::Test::TAG_NAME)).to eq("scenario with examples")

          expect(span.get_tag(Datadog::CI::Ext::Test::TAG_PARAMETERS)).to eq(
            "{\"arguments\":{\"num1\":\"#{index}\",\"num2\":\"#{index + 1}\",\"total\":\"#{index + index + 1}\"},\"metadata\":{}}"
          )
        else
          expect(span.get_tag(Datadog::CI::Ext::Test::TAG_NAME)).to eq(
            "scenario with examples, Examples (##{index + 1})"
          )
        end
        expect(span.get_tag(Datadog::CI::Ext::Test::TAG_SUITE)).to eq(
          "Datadog integration for parametrized tests at spec/datadog/ci/contrib/cucumber/features/with_parameters.feature"
        )
        expect(span.get_tag(Datadog::CI::Ext::Test::TAG_TEST_SUITE_ID)).to eq(test_suite_span.id.to_s)
        expect(span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
          Datadog::CI::Ext::Test::Status::PASS
        )
      end
    end
  end

  context "executing several features at once" do
    let(:expected_test_run_code) { 2 }

    let(:passing_test_suite) { test_suite_spans.find { |span| span.name =~ /passing/ } }
    let(:failing_test_suite) { test_suite_spans.find { |span| span.name =~ /failing/ } }

    it "creates a test suite span for each feature" do
      expect(test_suite_spans).to have(4).items
      expect(passing_test_suite.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::PASS
      )
      expect(failing_test_suite.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
    end

    it "connects tests with their respective test suites" do
      cucumber_scenario = test_spans.find { |span| span.name =~ /cucumber scenario/ }
      expect(cucumber_scenario.get_tag(Datadog::CI::Ext::Test::TAG_TEST_SUITE_ID)).to eq(
        passing_test_suite.id.to_s
      )

      cucumber_failing_scenario = test_spans.find { |span| span.name =~ /cucumber failing scenario/ }
      expect(cucumber_failing_scenario.get_tag(Datadog::CI::Ext::Test::TAG_TEST_SUITE_ID)).to eq(
        failing_test_suite.id.to_s
      )
    end

    it "sets failed status for module and session" do
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
      expect(test_module_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
    end
  end

  context "executing a feature with undefined steps in strict mode" do
    let(:expected_test_run_code) { 2 }
    let(:feature_file_to_run) { "passing.feature" }
    let(:args) do
      [
        "--strict",
        "-r",
        steps_file_for_run_path,
        features_path
      ]
    end

    it "marks test session as failed" do
      expect(test_session_span).not_to be_nil
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::FAIL)
    end

    it "marks test suite as failed" do
      expect(test_suite_span).not_to be_nil
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::FAIL)
    end

    it "marks undefined cucumber scenario as failed" do
      undefined_scenario_span = spans.find { |s| s.resource == "undefined scenario" }
      expect(undefined_scenario_span).not_to be_nil
      expect(undefined_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
      expect(undefined_scenario_span).to have_error_message("Undefined step: \"undefined\"")
    end

    it "marks pending cucumber scenario as failed" do
      pending_scenario_span = spans.find { |s| s.resource == "pending scenario" }
      expect(pending_scenario_span).not_to be_nil
      expect(pending_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::FAIL
      )
    end

    it "marks skipped cucumber scenario as skipped" do
      skipped_scenario_span = spans.find { |s| s.resource == "skipped scenario" }
      expect(skipped_scenario_span).not_to be_nil
      expect(skipped_scenario_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(
        Datadog::CI::Ext::Test::Status::SKIP
      )
    end
  end

  context "executing a feature where all scenarios are skipped" do
    let(:feature_file_to_run) { "skipped.feature" }

    it "marks all test spans as skipped" do
      expect(test_spans).to have(2).items
      expect(test_spans.map { |span| span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS) }.uniq).to eq(
        [Datadog::CI::Ext::Test::Status::SKIP]
      )
    end

    it "marks test session as passed" do
      expect(test_session_span).not_to be_nil
      expect(test_session_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::PASS)
    end

    it "marks test suite as skipped" do
      expect(test_suite_span).not_to be_nil
      expect(test_suite_span.get_tag(Datadog::CI::Ext::Test::TAG_STATUS)).to eq(Datadog::CI::Ext::Test::Status::SKIP)
    end
  end
end
