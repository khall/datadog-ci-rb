# frozen_string_literal: true

module Datadog
  module CI
    module Ext
      # Defines constants for Git tags
      module ITR
        API_TYPE_SETTINGS = "ci_app_test_service_libraries_settings"

        API_PATH_SETTINGS = "/api/v2/ci/libraries/tests/services/setting"
      end
    end
  end
end
