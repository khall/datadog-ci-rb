# frozen_string_literal: true

module Datadog
  module CI
    module Ext
      module Transport
        DEFAULT_DD_SITE = "datadoghq.com"

        HEADER_DD_API_KEY = "DD-API-KEY"
        HEADER_CONTENT_TYPE = "Content-Type"
        HEADER_CONTENT_ENCODING = "Content-Encoding"
        HEADER_EVP_SUBDOMAIN = "X-Datadog-EVP-Subdomain"
        HEADER_CONTAINER_ID = "Datadog-Container-ID"

        EVP_PROXY_V2_PATH_PREFIX = "/evp_proxy/v2/"
        EVP_PROXY_V4_PATH_PREFIX = "/evp_proxy/v4/"
        EVP_PROXY_PATH_PREFIXES = [EVP_PROXY_V4_PATH_PREFIX, EVP_PROXY_V2_PATH_PREFIX].freeze
        EVP_PROXY_COMPRESSION_SUPPORTED = {
          EVP_PROXY_V4_PATH_PREFIX => true,
          EVP_PROXY_V2_PATH_PREFIX => false
        }

        TEST_VISIBILITY_INTAKE_HOST_PREFIX = "citestcycle-intake"
        TEST_VISIBILITY_INTAKE_PATH = "/api/v2/citestcycle"

        TEST_COVERAGE_INTAKE_HOST_PREFIX = "citestcov-intake"
        TEST_COVERAGE_INTAKE_PATH = "/api/v2/citestcov"

        DD_API_HOST_PREFIX = "api"
        DD_API_SETTINGS_PATH = "/api/v2/libraries/tests/services/setting"
        DD_API_SETTINGS_TYPE = "ci_app_test_service_libraries_settings"
        DD_API_SETTINGS_RESPONSE_DIG_KEYS = %w[data attributes].freeze
        DD_API_SETTINGS_RESPONSE_ITR_ENABLED_KEY = "itr_enabled"
        DD_API_SETTINGS_RESPONSE_CODE_COVERAGE_KEY = "code_coverage"
        DD_API_SETTINGS_RESPONSE_TESTS_SKIPPING_KEY = "tests_skipping"
        DD_API_SETTINGS_RESPONSE_REQUIRE_GIT_KEY = "require_git"
        DD_API_SETTINGS_RESPONSE_DEFAULT = {DD_API_SETTINGS_RESPONSE_ITR_ENABLED_KEY => false}.freeze

        CONTENT_TYPE_MESSAGEPACK = "application/msgpack"
        CONTENT_TYPE_JSON = "application/json"
        CONTENT_TYPE_MULTIPART_FORM_DATA = "multipart/form-data"
        CONTENT_ENCODING_GZIP = "gzip"
      end
    end
  end
end
