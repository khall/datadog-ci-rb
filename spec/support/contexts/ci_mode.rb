# CI mode shared context sets up the CI recorder and configures the CI mode for tracer like customers do.
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

  let(:recorder) { Datadog.send(:components).ci_recorder }

  before do
    allow_any_instance_of(Datadog::Core::Remote::Negotiation).to(
      receive(:endpoint?).with("/evp_proxy/v4/").and_return(true)
    )

    allow(Datadog::CI::Utils::TestRun).to receive(:command).and_return(test_command)

    allow_any_instance_of(Datadog::CI::Transport::RemoteSettingsApi).to receive(:fetch_library_settings).and_return(
      double(
        "remote_settings_api_response",
        payload: {
          "itr_enabled" => itr_enabled,
          "code_coverage" => code_coverage_enabled,
          "tests_skipping" => tests_skipping_enabled
        }
      )
    )

    allow_any_instance_of(Datadog::CI::ITR::Coverage::Transport).to receive(:send_events).and_return([])

    Datadog.configure do |c|
      c.ci.enabled = ci_enabled
      c.ci.force_test_level_visibility = force_test_level_visibility
      c.ci.itr_enabled = itr_enabled
      unless integration_name == :no_instrument
        c.ci.instrument integration_name, integration_options
      end
    end
  end

  after do
    ::Datadog::Tracing.shutdown!
  end
end
