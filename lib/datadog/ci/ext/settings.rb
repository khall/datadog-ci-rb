# frozen_string_literal: true

module Datadog
  module CI
    module Ext
      # Defines constants for test tags
      module Settings
        ENV_MODE_ENABLED = "DD_TRACE_CI_ENABLED"
        ENV_AGENTLESS_MODE_ENABLED = "DD_CIVISIBILITY_AGENTLESS_ENABLED"
        ENV_AGENTLESS_URL = "DD_CIVISIBILITY_AGENTLESS_URL"
        ENV_EXPERIMENTAL_TEST_SUITE_LEVEL_VISIBILITY_ENABLED = "DD_CIVISIBILITY_EXPERIMENTAL_TEST_SUITE_LEVEL_VISIBILITY_ENABLED"
        ENV_USE_TEST_LEVEL_VISIBILITY = "DD_CIVISIBILITY_USE_TEST_LEVEL_VISIBILITY"

        # Source: https://docs.datadoghq.com/getting_started/site/
        DD_SITE_ALLOWLIST = [
          "datadoghq.com",
          "us3.datadoghq.com",
          "us5.datadoghq.com",
          "datadoghq.eu",
          "ddog-gov.com",
          "ap1.datadoghq.com"
        ].freeze
      end
    end
  end
end
