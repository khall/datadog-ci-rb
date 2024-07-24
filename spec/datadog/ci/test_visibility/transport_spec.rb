# frozen_string_literal: true

require_relative "../../../../lib/datadog/ci/test_visibility/transport"

RSpec.describe Datadog::CI::TestVisibility::Transport do
  include_context "Telemetry spy"
  include_context "CI mode activated" do
    let(:integration_name) { :rspec }
  end

  subject(:transport) do
    described_class.new(
      api: api,
      dd_env: dd_env,
      serializers_factory: serializers_factory,
      max_payload_size: max_payload_size
    )
  end

  before do
    allow(Datadog.logger).to receive(:warn)
  end

  let(:dd_env) { nil }
  let(:serializers_factory) { Datadog::CI::TestVisibility::Serializers::Factories::TestLevel }
  let(:max_payload_size) { 4 * 1024 * 1024 }

  let(:api) { spy(:api) }

  describe "#send_events" do
    context "with a single trace and a single span" do
      subject { transport.send_events([trace]) }

      before do
        produce_test_trace
      end

      it "sends correct payload" do
        subject

        expect(api).to have_received(:citestcycle_request) do |args|
          expect(args[:path]).to eq("/api/v2/citestcycle")

          payload = MessagePack.unpack(args[:payload])
          expect(payload["version"]).to eq(1)

          metadata = payload["metadata"]["*"]
          expect(metadata).to include("runtime-id", "library_version")
          expect(metadata["language"]).to eq("ruby")

          events = payload["events"]
          expect(events.count).to eq(1)
          expect(events.first["content"]["resource"]).to include("calculator_tests")
        end
      end

      it "returns responses" do
        responses = subject

        expect(responses.count).to eq(1)
        # spy returns itself
        expect(responses.first).to eq(api)
      end

      it_behaves_like "emits telemetry metric", :inc, "events_enqueued_for_serialization", 1
      it_behaves_like "emits telemetry metric", :distribution, "endpoint_payload.events_count", 1

      it "tags event with test_cycle endpoint" do
        subject

        expect(telemetry_metric(:distribution, "endpoint_payload.events_count")).to(
          have_attributes(tags: {"endpoint" => "test_cycle"})
        )
      end
    end

    context "with dd_env defined" do
      let(:dd_env) { "ci" }
      before do
        produce_test_trace
      end

      it "sends correct payload including env" do
        subject.send_events([trace])

        expect(api).to have_received(:citestcycle_request) do |args|
          payload = MessagePack.unpack(args[:payload])

          metadata = payload["metadata"]["*"]
          expect(metadata["env"]).to eq("ci")
        end
      end
    end

    context "with itr correlation id" do
      let(:serializers_factory) { Datadog::CI::TestVisibility::Serializers::Factories::TestSuiteLevel }

      before do
        allow_any_instance_of(Datadog::CI::TestOptimisation::Component).to receive(:correlation_id).and_return("correlation-id")

        produce_test_session_trace
      end

      it "passes itr correlation id to serializer" do
        subject.send_events([trace_for_span(first_test_span)])

        expect(api).to have_received(:citestcycle_request) do |args|
          payload = MessagePack.unpack(args[:payload])
          expect(payload["version"]).to eq(1)

          events = payload["events"]
          expect(events.count).to eq(1)
          expect(events.first["content"]["resource"]).to include("calculator_tests")
          expect(events.first["content"]["itr_correlation_id"]).to eq("correlation-id")
        end
      end
    end

    context "multiple traces with 2 spans each" do
      subject { transport.send_events(traces) }

      let(:traces_count) { 2 }
      let(:expected_events_count) { 4 }

      before do
        2.times { produce_test_trace(with_http_span: true) }
      end

      it "sends event for each of spans" do
        subject

        expect(api).to have_received(:citestcycle_request) do |args|
          payload = MessagePack.unpack(args[:payload])
          events = payload["events"]
          expect(events.count).to eq(expected_events_count)
        end
      end

      it_behaves_like "emits telemetry metric", :inc, "events_enqueued_for_serialization", 4
      it_behaves_like "emits telemetry metric", :distribution, "endpoint_payload.events_count", 4

      context "when some spans are broken" do
        let(:expected_events_count) { 3 }
        let(:http_span) { spans.find { |span| span.type == "http" } }

        before do
          http_span.start_time = Time.at(0)
        end

        it "filters out invalid events" do
          subject

          expect(api).to have_received(:citestcycle_request) do |args|
            payload = MessagePack.unpack(args[:payload])

            events = payload["events"]
            expect(events.count).to eq(expected_events_count)

            span_events = events.filter { |e| e["type"] == "span" }
            expect(span_events.count).to eq(1)
          end
        end

        it "logs warning that events were filtered out" do
          subject

          expect(Datadog.logger).to have_received(:warn).with(
            "Invalid event skipped: " \
            "Datadog::CI::TestVisibility::Serializers::Span(id:#{http_span.id},name:#{http_span.name}) " \
            "Errors: {\"start\"=>#<Set: {\"must be greater than or equal to 946684800000000000\"}>}"
          )
        end

        it_behaves_like "emits telemetry metric", :inc, "events_enqueued_for_serialization", 3
        it_behaves_like "emits telemetry metric", :distribution, "endpoint_payload.events_count", 3
      end

      context "when chunking is used" do
        # one test event is approximately 1000 bytes currently
        # ATTENTION: might break if more data is added to test spans in #produce_test_trace method
        let(:max_payload_size) { 2000 }

        it "filters out invalid events" do
          responses = subject

          expect(api).to have_received(:citestcycle_request).twice
          expect(responses.count).to eq(2)
        end

        it_behaves_like "emits telemetry metric", :inc, "events_enqueued_for_serialization", 4
      end

      context "when max_payload-size is too small" do
        # one test event is approximately 1000 bytes currently
        # ATTENTION: might break if more data is added to test spans in #produce_test_trace method
        let(:max_payload_size) { 1 }

        it "does not send events that are larger than max size" do
          subject

          expect(api).not_to have_received(:citestcycle_request)
        end
      end
    end

    context "when all events are invalid" do
      before do
        produce_test_trace

        span.start_time = Time.at(0)
      end

      it "does not send anything" do
        subject.send_events(traces)

        expect(api).not_to have_received(:citestcycle_request)
      end
    end
  end
end
