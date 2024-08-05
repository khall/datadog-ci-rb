require_relative "../../../../lib/datadog/ci/test_retries/component"

RSpec.describe Datadog::CI::TestRetries::Component do
  let(:library_settings) { instance_double(Datadog::CI::Remote::LibrarySettings) }
  let(:retry_failed_tests_max_attempts) { 1 }
  let(:retry_failed_tests_total_limit) { 12 }

  subject(:component) do
    described_class.new(
      retry_failed_tests_max_attempts: retry_failed_tests_max_attempts,
      retry_failed_tests_total_limit: retry_failed_tests_total_limit
    )
  end

  describe "#configure" do
    subject { component.configure(library_settings) }

    context "when flaky test retries are enabled" do
      before do
        allow(library_settings).to receive(:flaky_test_retries_enabled?).and_return(true)
      end

      it "enables retrying failed tests" do
        subject

        expect(component.retry_failed_tests_enabled).to be true
      end
    end

    context "when flaky test retries are disabled" do
      before do
        allow(library_settings).to receive(:flaky_test_retries_enabled?).and_return(false)
      end

      it "disables retrying failed tests" do
        subject

        expect(component.retry_failed_tests_enabled).to be false
      end
    end
  end

  describe "#retry_failed_tests_max_attempts" do
    subject { component.retry_failed_tests_max_attempts }

    it { is_expected.to eq(retry_failed_tests_max_attempts) }
  end

  describe "#retry_failed_tests_total_limit" do
    subject { component.retry_failed_tests_total_limit }

    it { is_expected.to eq(retry_failed_tests_total_limit) }
  end
end
