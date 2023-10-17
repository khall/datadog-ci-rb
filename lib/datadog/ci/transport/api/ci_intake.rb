# frozen_string_literal: true

require_relative "base"
require_relative "../http"

module Datadog
  module CI
    module Transport
      module Api
        class CIIntake < Base
          attr_reader :api_key, :http

          def initialize(api_key:, url:)
            @api_key = api_key

            uri = URI.parse(url)
            raise "Invalid agentless mode URL: #{url}" if uri.host.nil?

            @http = Datadog::CI::Transport::HTTP.new(
              host: uri.host,
              port: uri.port,
              ssl: uri.scheme == "https" || uri.port == 443,
              compress: true
            )
          end

          def request(path:, payload:, verb: "post")
            http.request(
              path: path,
              payload: payload,
              method: verb,
              headers: headers
            )
          end

          private

          def headers
            headers = super
            headers[Ext::Transport::HEADER_DD_API_KEY] = api_key
            headers
          end
        end
      end
    end
  end
end
