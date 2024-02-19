require_relative "../../../../../lib/datadog/ci/transport/api/evp_proxy"

RSpec.describe Datadog::CI::Transport::Api::EvpProxy do
  subject do
    described_class.new(http: http, path_prefix: path_prefix)
  end

  let(:http) { double(:http) }
  let(:path_prefix) { "/evp_proxy/v2/" }

  describe "#request" do
    let(:container_id) { nil }

    before do
      allow(Datadog::CI::Transport::HTTP).to receive(:new).and_return(http)
      expect(Datadog::Core::Environment::Container).to receive(:container_id).and_return(container_id)
    end

    context "with path starting from / character" do
      it "produces correct headers and forwards request to HTTP layer prepending path with evp_proxy" do
        expect(http).to receive(:request).with(
          path: "/evp_proxy/v2/path",
          payload: "payload",
          verb: "post",
          headers: {
            "Content-Type" => "application/msgpack",
            "X-Datadog-EVP-Subdomain" => "citestcycle-intake"
          }
        )

        subject.request(path: "/path", payload: "payload")
      end
    end

    context "with path without / in the beginning" do
      it "constructs evp proxy path correctly" do
        expect(http).to receive(:request).with(
          path: "/evp_proxy/v2/path",
          payload: "payload",
          verb: "post",
          headers: {
            "Content-Type" => "application/msgpack",
            "X-Datadog-EVP-Subdomain" => "citestcycle-intake"
          }
        )

        subject.request(path: "path", payload: "payload")
      end
    end

    context "with different path_prefix" do
      let(:path_prefix) { "/evp_proxy/v4" }

      it "constructs evp proxy path using this prefix" do
        expect(http).to receive(:request).with(
          path: "/evp_proxy/v4/path",
          payload: "payload",
          verb: "post",
          headers: {
            "Content-Type" => "application/msgpack",
            "X-Datadog-EVP-Subdomain" => "citestcycle-intake"
          }
        )

        subject.request(path: "path", payload: "payload")
      end
    end

    context "with container id" do
      let(:container_id) { "container-id" }

      it "adds an additional Datadog-Container-ID header" do
        expect(http).to receive(:request).with(
          path: "/evp_proxy/v2/path",
          payload: "payload",
          verb: "post",
          headers: {
            "Content-Type" => "application/msgpack",
            "X-Datadog-EVP-Subdomain" => "citestcycle-intake",
            "Datadog-Container-ID" => "container-id"
          }
        )

        subject.request(path: "/path", payload: "payload")
      end
    end
  end
end
