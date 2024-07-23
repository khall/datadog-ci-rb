# frozen_string_literal: true

require_relative "../../../../lib/datadog/ci/test_visibility/telemetry"

RSpec.describe Datadog::CI::TestVisibility::Telemetry do
  describe ".event_created" do
    subject(:event_created) { described_class.event_created(span) }

    before do
      expect(Datadog::CI::Utils::Telemetry).to receive(:inc)
        .with(Datadog::CI::Ext::Telemetry::METRIC_EVENT_CREATED, 1, expected_tags)
    end

    context "test session span" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_session",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST_SESSION,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec",
            Datadog::CI::Ext::Environment::TAG_PROVIDER_NAME => "gha"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::SESSION,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec"
        }
      end

      it { event_created }
    end

    context "test module span without CI provider" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_module",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST_MODULE,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::MODULE,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec",
          Datadog::CI::Ext::Telemetry::TAG_IS_UNSUPPORTED_CI => "true"
        }
      end

      it { event_created }
    end

    context "test suite span" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_session",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST_SUITE,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec",
            Datadog::CI::Ext::Environment::TAG_PROVIDER_NAME => "gha"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::SUITE,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec"
        }
      end

      it { event_created }
    end

    context "test span with codeowners" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_session",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec",
            Datadog::CI::Ext::Environment::TAG_PROVIDER_NAME => "gha",
            Datadog::CI::Ext::Test::TAG_CODEOWNERS => "@owner",
            Datadog::CI::Ext::Test::TAG_IS_RUM_ACTIVE => "true",
            Datadog::CI::Ext::Test::TAG_BROWSER_DRIVER => "selenium"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::TEST,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec",
          Datadog::CI::Ext::Telemetry::TAG_HAS_CODEOWNER => "true"
        }
      end

      it { event_created }
    end
  end

  describe ".event_finished" do
    subject(:event_finished) { described_class.event_finished(span) }

    before do
      expect(Datadog::CI::Utils::Telemetry).to receive(:inc)
        .with(Datadog::CI::Ext::Telemetry::METRIC_EVENT_FINISHED, 1, expected_tags)
    end

    context "test session span" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_session",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST_SESSION,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec",
            Datadog::CI::Ext::Environment::TAG_PROVIDER_NAME => "gha"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::SESSION,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec"
        }
      end

      it { event_finished }
    end

    context "test module span without CI provider" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_module",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST_MODULE,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::MODULE,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec",
          Datadog::CI::Ext::Telemetry::TAG_IS_UNSUPPORTED_CI => "true"
        }
      end

      it { event_finished }
    end

    context "test suite span" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_session",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST_SUITE,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec",
            Datadog::CI::Ext::Environment::TAG_PROVIDER_NAME => "gha"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::SUITE,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec"
        }
      end

      it { event_finished }
    end

    context "test span with codeowners" do
      let(:span) do
        Datadog::Tracing::SpanOperation.new(
          "test_session",
          type: Datadog::CI::Ext::AppTypes::TYPE_TEST,
          tags: {
            Datadog::CI::Ext::Test::TAG_FRAMEWORK => "rspec",
            Datadog::CI::Ext::Environment::TAG_PROVIDER_NAME => "gha",
            Datadog::CI::Ext::Test::TAG_CODEOWNERS => "@owner",
            Datadog::CI::Ext::Test::TAG_IS_RUM_ACTIVE => "true",
            Datadog::CI::Ext::Test::TAG_BROWSER_DRIVER => "selenium"
          }
        )
      end

      let(:expected_tags) do
        {
          Datadog::CI::Ext::Telemetry::TAG_EVENT_TYPE => Datadog::CI::Ext::Telemetry::EventType::TEST,
          Datadog::CI::Ext::Telemetry::TAG_TEST_FRAMEWORK => "rspec",
          Datadog::CI::Ext::Telemetry::TAG_HAS_CODEOWNER => "true",
          Datadog::CI::Ext::Telemetry::TAG_IS_RUM => "true",
          Datadog::CI::Ext::Telemetry::TAG_BROWSER_DRIVER => "selenium"
        }
      end

      it { event_finished }
    end
  end
end
