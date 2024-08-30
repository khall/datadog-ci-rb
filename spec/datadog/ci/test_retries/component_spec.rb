require_relative "../../../../lib/datadog/ci/test_retries/component"

RSpec.describe Datadog::CI::TestRetries::Component do
  let(:library_settings) do
    instance_double(
      Datadog::CI::Remote::LibrarySettings,
      flaky_test_retries_enabled?: remote_flaky_test_retries_enabled,
      early_flake_detection_enabled?: remote_early_flake_detection_enabled,
      slow_test_retries: slow_test_retries,
      faulty_session_threshold: retry_new_tests_percentage_limit
    )
  end

  let(:retry_failed_tests_enabled) { true }
  let(:retry_failed_tests_max_attempts) { 1 }
  let(:retry_failed_tests_total_limit) { 12 }
  let(:retry_new_tests_enabled) { true }
  let(:retry_new_tests_percentage_limit) { 30 }

  let(:remote_flaky_test_retries_enabled) { false }
  let(:remote_early_flake_detection_enabled) { false }

  let(:slow_test_retries) do
    instance_double(
      Datadog::CI::Remote::SlowTestRetries,
      max_attempts_for_duration: 10
    )
  end

  subject(:component) do
    described_class.new(
      retry_failed_tests_enabled: retry_failed_tests_enabled,
      retry_failed_tests_max_attempts: retry_failed_tests_max_attempts,
      retry_failed_tests_total_limit: retry_failed_tests_total_limit,
      retry_new_tests_enabled: retry_new_tests_enabled
    )
  end

  describe "#configure" do
    subject { component.configure(library_settings) }

    context "when flaky test retries are enabled" do
      let(:remote_flaky_test_retries_enabled) { true }

      it "enables retrying failed tests" do
        subject

        expect(component.retry_failed_tests_enabled).to be true
      end
    end

    context "when flaky test retries are disabled" do
      let(:remote_flaky_test_retries_enabled) { false }

      it "disables retrying failed tests" do
        subject

        expect(component.retry_failed_tests_enabled).to be false
      end
    end

    context "when flaky test retries are disabled in local settings" do
      let(:retry_failed_tests_enabled) { false }
      let(:remote_flaky_test_retries_enabled) { true }

      it "disables retrying failed tests even if it's enabled remotely" do
        subject

        expect(component.retry_failed_tests_enabled).to be false
      end
    end

    context "when early flake detection is enabled" do
      let(:remote_early_flake_detection_enabled) { true }

      it "enables retrying new tests" do
        subject

        expect(component.retry_new_tests_enabled).to be true
        expect(component.retry_new_tests_duration_thresholds.max_attempts_for_duration(1.2)).to eq(10)
        expect(component.retry_new_tests_percentage_limit).to eq(retry_new_tests_percentage_limit)
      end
    end

    context "when early flake detection is disabled" do
      let(:remote_early_flake_detection_enabled) { false }

      it "disables retrying new tests" do
        subject

        expect(component.retry_new_tests_enabled).to be false
      end
    end

    context "when early flake detection is disabled in local settings" do
      let(:retry_new_tests_enabled) { false }
      let(:remote_early_flake_detection_enabled) { true }

      it "disables retrying new tests even if it's enabled remotely" do
        subject

        expect(component.retry_new_tests_enabled).to be false
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

  describe "#build_strategy" do
    subject { component.build_strategy(test_span) }

    let(:test_failed) { false }
    let(:test_span) { instance_double(Datadog::CI::Test, failed?: test_failed) }

    before do
      component.configure(library_settings)
    end

    context "when retry failed tests is enabled" do
      let(:remote_flaky_test_retries_enabled) { true }

      context "when test span is failed" do
        let(:test_failed) { true }

        context "when failed tests retry limit is not reached" do
          let(:retry_failed_tests_total_limit) { 1 }

          it "creates RetryFailed strategy" do
            expect(subject).to be_a(Datadog::CI::TestRetries::Strategy::RetryFailed)
            expect(subject.max_attempts).to eq(retry_failed_tests_max_attempts)
          end
        end

        context "when failed tests retry limit is reached" do
          let(:retry_failed_tests_total_limit) { 1 }

          before do
            component.build_strategy(test_span)
          end

          it { is_expected.to be_a(Datadog::CI::TestRetries::Strategy::NoRetry) }
        end

        context "when failed tests retry limit is reached with multithreading test runner" do
          let(:threads_count) { 10 }
          let(:retry_failed_tests_total_limit) { threads_count }

          before do
            threads = (1..threads_count).map do
              Thread.new { component.build_strategy(test_span) }
            end

            threads.each(&:join)
          end

          it "correctly exhausts failed tests limit" do
            is_expected.to be_a(Datadog::CI::TestRetries::Strategy::NoRetry)
          end
        end
      end

      context "when test span is passed" do
        let(:test_failed) { false }

        it { is_expected.to be_a(Datadog::CI::TestRetries::Strategy::NoRetry) }
      end
    end

    context "when retry failed tests is disabled" do
      it { is_expected.to be_a(Datadog::CI::TestRetries::Strategy::NoRetry) }
    end
  end

  describe "#with_retries" do
    include_context "CI mode activated" do
      let(:flaky_test_retries_enabled) { true }
    end

    let(:test_failed) { false }
    let(:test_span) do
      instance_double(
        Datadog::CI::Test,
        failed?: test_failed,
        passed?: false,
        set_tag: true,
        get_tag: true,
        skipped?: false,
        type: "test"
      )
    end

    subject(:runs_count) do
      runs_count = 0
      component.with_retries do
        runs_count += 1

        # run callback manually
        Datadog.send(:components).test_visibility.send(:on_test_finished, test_span)
      end

      runs_count
    end

    before do
      component.configure(library_settings)
    end

    context "when no retries strategy is used" do
      it { is_expected.to eq(1) }
    end

    context "when retried failed tests strategy is used" do
      let(:remote_flaky_test_retries_enabled) { true }

      context "when test span is failed" do
        let(:test_failed) { true }
        let(:retry_failed_tests_max_attempts) { 4 }

        it { is_expected.to eq(retry_failed_tests_max_attempts + 1) }
      end

      context "when test span is passed" do
        let(:test_failed) { false }

        it { is_expected.to eq(1) }
      end
    end
  end
end
