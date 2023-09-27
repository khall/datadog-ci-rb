# frozen_string_literal: true

require "msgpack"
require "datadog/core/encoding"
require "datadog/core/environment/identity"
# use it to chunk payloads by size
# require "datadog/core/chunker"

require_relative "serializers"
require_relative "../ext/transport"
require_relative "../transport/http"

module Datadog
  module CI
    module TestVisibility
      class Transport
        # TODO: rename Serializers module
        def initialize(api_key:, site: "datadoghq.com", serializer: Datadog::CI::TestVisibility::Serializers)
          @serializer = serializer
          @api_key = api_key
          @http = Datadog::CI::Transport::HTTP.new(
            host: "#{Ext::Transport::TEST_VISIBILITY_INTAKE_HOST_PREFIX}.#{site}",
            port: 443
          )
        end

        def send_traces(traces)
          return [] if traces.nil? || traces.empty?

          events = serialize_traces(traces)

          if events.empty?
            Datadog.logger.debug("[TestVisibility::Transport] empty events list, skipping send")
            return []
          end

          payload = Payload.new(events)
          encoded_payload = encoder.encode(payload)

          response = @http.request(
            path: Datadog::CI::Ext::Transport::TEST_VISIBILITY_INTAKE_PATH,
            payload: encoded_payload,
            headers: {
              Ext::Transport::HEADER_DD_API_KEY => @api_key,
              Ext::Transport::HEADER_CONTENT_TYPE => Ext::Transport::CONTENT_TYPE_MESSAGEPACK
            }
          )

          # Tracing writers expect an array of responses
          [response]
        end

        private

        def serialize_traces(traces)
          # TODO: replace map.filter with filter_map when 1.0 is released
          traces.flat_map do |trace|
            trace.spans.map do |span|
              event = @serializer.convert_span_to_serializable_event(trace, span)

              if event.valid?
                event
              else
                Datadog.logger.debug { "Invalid span skipped: #{span}" }
                nil
              end
            end.filter { |event| !event.nil? }
          end
        end

        def encoder
          Datadog::Core::Encoding::MsgpackEncoder
        end

        # represents payload with some subset of serializable events to be sent to CI-APP intake
        class Payload
          def initialize(events)
            @events = events
          end

          def to_msgpack(packer)
            packer ||= MessagePack::Packer.new

            packer.write_map_header(3) # Set header with how many elements in the map

            packer.write("version")
            packer.write(1)

            packer.write("metadata")
            packer.write_map_header(1)

            packer.write("*")
            packer.write_map_header(3)

            packer.write("runtime-id")
            packer.write(Datadog::Core::Environment::Identity.id)

            packer.write("language")
            packer.write(Datadog::Core::Environment::Identity.lang)

            packer.write("library_version")
            packer.write(Datadog::CI::VERSION::STRING)

            packer.write("events")
            # this is required for jruby to pack array correctly
            # on CRuby it is enough to call `packer.write(@events)`
            packer.write_array_header(@events.size)
            @events.each do |event|
              packer.write(event)
            end
          end
        end
      end
    end
  end
end
