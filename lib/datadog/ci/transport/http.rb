# frozen_string_literal: true

require "delegate"
require "datadog/core/transport/http/adapters/net"
require "datadog/core/transport/http/env"
require "datadog/core/transport/request"

require_relative "gzip"
require_relative "../ext/transport"

module Datadog
  module CI
    module Transport
      class HTTP
        attr_reader \
          :host,
          :port,
          :ssl,
          :timeout,
          :compress

        DEFAULT_TIMEOUT = 30

        def initialize(host:, timeout: DEFAULT_TIMEOUT, port: nil, ssl: true, compress: false)
          @host = host
          @port = port
          @timeout = timeout
          @ssl = ssl.nil? ? true : ssl
          @compress = compress.nil? ? false : compress
        end

        def request(path:, payload:, headers:, verb: "post")
          if compress
            headers[Ext::Transport::HEADER_CONTENT_ENCODING] = Ext::Transport::CONTENT_ENCODING_GZIP
            payload = Gzip.compress(payload)
          end

          Datadog.logger.debug do
            "Sending #{verb} request: host=#{host}; port=#{port}; ssl_enabled=#{ssl}; " \
              "compression_enabled=#{compress}; path=#{path}; payload_size=#{payload.size}"
          end

          response = ResponseDecorator.new(
            adapter.call(
              build_env(path: path, payload: payload, headers: headers, verb: verb)
            )
          )

          Datadog.logger.debug do
            "Received server response: #{response.inspect}"
          end

          response
        end

        private

        def build_env(path:, payload:, headers:, verb:)
          env = Datadog::Core::Transport::HTTP::Env.new(
            Datadog::Core::Transport::Request.new
          )
          env.body = payload
          env.path = path
          env.headers = headers
          env.verb = verb
          env
        end

        def adapter
          settings = AdapterSettings.new(hostname: host, port: port, ssl: ssl, timeout_seconds: timeout)
          @adapter ||= Datadog::Core::Transport::HTTP::Adapters::Net.new(settings)
        end

        # this is needed because Datadog::Tracing::Writer is not fully compatiple with Datadog::Core::Transport
        # TODO: remove when CI implements its own worker
        class ResponseDecorator < ::SimpleDelegator
          def trace_count
            0
          end
        end

        class AdapterSettings
          attr_reader :hostname, :port, :ssl, :timeout_seconds

          def initialize(hostname:, port: nil, ssl: true, timeout_seconds: nil)
            @hostname = hostname
            @port = port
            @ssl = ssl
            @timeout_seconds = timeout_seconds
          end

          def ==(other)
            hostname == other.hostname && port == other.port && ssl == other.ssl &&
              timeout_seconds == other.timeout_seconds
          end
        end
      end
    end
  end
end
