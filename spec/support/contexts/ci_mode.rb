# frozen_string_literal: true

# CI mode shared context sets up the CI test_visibility and configures the CI mode for tracer like customers do.
# Example usage:
#
# include_context "CI mode activated" do
#   let(:integration_name) { :cucumber }
#   let(:integration_options) { {service_name: "jalapenos"} }
# end

require_relative "../coverage_helpers"

RSpec.shared_context "CI mode activated" do
  include CoverageHelpers

  let(:test_command) { "command" }
  let(:integration_name) { :no_instrument }
  let(:integration_options) { {} }

  let(:ci_enabled) { true }
  let(:force_test_level_visibility) { false }
  let(:itr_enabled) { false }
  let(:code_coverage_enabled) { false }
  let(:tests_skipping_enabled) { false }
  let(:git_metadata_upload_enabled) { false }
  let(:require_git) { false }
  let(:bundle_path) { nil }
  let(:use_single_threaded_coverage) { false }
  let(:flaky_test_retries_enabled) { false }
  let(:early_flake_detection_enabled) { false }
  let(:faulty_session_threshold) { 30 }

  let(:retry_failed_tests_max_attempts) { 5 }
  let(:retry_failed_tests_total_limit) { 100 }

  let(:slow_test_retries_payload) do
    {
      "5s" => 10,
      "10s" => 5,
      "30s" => 3,
      "10m" => 2
    }
  end
  let(:slow_test_retries) { Datadog::CI::Remote::SlowTestRetries.new(slow_test_retries_payload) }

  let(:itr_correlation_id) { "itr_correlation_id" }
  let(:itr_skippable_tests) { [] }

  let(:skippable_tests_response) do
    instance_double(
      Datadog::CI::TestOptimisation::Skippable::Response,
      ok?: true,
      correlation_id: itr_correlation_id,
      tests: itr_skippable_tests
    )
  end

  let(:test_visibility) { Datadog.send(:components).test_visibility }

  before do
    setup_test_coverage_writer!

    allow_any_instance_of(Datadog::Core::Remote::Negotiation).to(
      receive(:endpoint?).with("/evp_proxy/v4/").and_return(true)
    )

    allow(Datadog::CI::Utils::TestRun).to receive(:command).and_return(test_command)

    allow_any_instance_of(Datadog::CI::Remote::LibrarySettingsClient).to receive(:fetch).and_return(
      instance_double(
        Datadog::CI::Remote::LibrarySettings,
        payload: {
          "itr_enabled" => itr_enabled,
          "code_coverage" => code_coverage_enabled,
          "tests_skipping" => tests_skipping_enabled
        },
        require_git?: require_git,
        itr_enabled?: itr_enabled,
        code_coverage_enabled?: code_coverage_enabled,
        tests_skipping_enabled?: tests_skipping_enabled,
        flaky_test_retries_enabled?: flaky_test_retries_enabled,
        early_flake_detection_enabled?: early_flake_detection_enabled,
        slow_test_retries: slow_test_retries,
        faulty_session_threshold: faulty_session_threshold
      ),
      # This is for the second call to fetch_library_settings
      instance_double(
        Datadog::CI::Remote::LibrarySettings,
        payload: {
          "itr_enabled" => itr_enabled,
          "code_coverage" => !code_coverage_enabled,
          "tests_skipping" => !tests_skipping_enabled
        },
        require_git?: !require_git,
        itr_enabled?: itr_enabled,
        code_coverage_enabled?: !code_coverage_enabled,
        tests_skipping_enabled?: !tests_skipping_enabled,
        flaky_test_retries_enabled?: flaky_test_retries_enabled,
        early_flake_detection_enabled?: early_flake_detection_enabled,
        slow_test_retries: slow_test_retries,
        faulty_session_threshold: faulty_session_threshold
      )
    )
    allow_any_instance_of(Datadog::CI::TestOptimisation::Skippable).to receive(:fetch_skippable_tests).and_return(skippable_tests_response)
    allow_any_instance_of(Datadog::CI::TestOptimisation::Coverage::Transport).to receive(:send_events).and_return([])

    Datadog.configure do |c|
      # library switch
      c.ci.enabled = ci_enabled

      # test visibility
      c.ci.force_test_level_visibility = force_test_level_visibility

      # test optimisation
      c.ci.itr_enabled = itr_enabled
      c.ci.git_metadata_upload_enabled = git_metadata_upload_enabled
      c.ci.itr_code_coverage_excluded_bundle_path = bundle_path
      c.ci.itr_code_coverage_use_single_threaded_mode = use_single_threaded_coverage

      # test retries
      c.ci.retry_failed_tests_max_attempts = retry_failed_tests_max_attempts
      c.ci.retry_failed_tests_total_limit = retry_failed_tests_total_limit

      # instrumentation
      unless integration_name == :no_instrument
        c.ci.instrument integration_name, integration_options
      end
    end
  end

  after do
    ::Datadog::Tracing.shutdown!

    Datadog::CI.send(:test_optimisation)&.shutdown!
    Datadog::CI.send(:test_visibility)&.shutdown!

    Datadog.configure do |c|
      c.ci.enabled = false
    end
  end
end
