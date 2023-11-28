require_relative "../../../../../lib/datadog/ci/test_visibility/serializers/span"
require_relative "../../../../../lib/datadog/ci/recorder"

RSpec.describe Datadog::CI::TestVisibility::Serializers::Span do
  include_context "CI mode activated" do
    let(:integration_name) { :rspec }
  end

  include_context "Test visibility event serialized" do
    subject { described_class.new(trace_for_span(tracer_span), tracer_span) }
  end

  let(:test_span) do
    spans.find { |span| span.type == "test" }
  end

  let(:tracer_span) do
    spans.find { |span| span.type != "test" }
  end

  describe "#to_msgpack" do
    context "traced a single test execution with Recorder" do
      before do
        produce_test_trace(with_http_span: true)
      end

      it "serializes test event to messagepack" do
        expect_event_header(type: "span")
        expect(content).to include(
          {
            "trace_id" => trace.id,
            "span_id" => first_other_span.id,
            "parent_id" => first_test_span.id,
            "name" => "http-call",
            "service" => "net-http",
            "type" => "http",
            "error" => 0,
            "resource" => "http-call"
          }
        )
        expect(content).to include("start", "duration")

        expect(meta).to include(
          {
            "custom_tag" => "custom_tag_value",
            "_dd.origin" => "ciapp-test"
          }
        )
        expect(metrics).to eq({"_dd.top_level" => 1.0, "custom_metric" => 42})
      end
    end
  end

  describe "valid?" do
    context "required fields" do
      context "when not present" do
        before do
          produce_test_trace(with_http_span: true)

          tracer_span.name = nil
        end

        it { is_expected.not_to be_valid }
      end
    end
  end
end
