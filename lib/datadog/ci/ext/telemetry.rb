# frozen_string_literal: true

module Datadog
  module CI
    module Ext
      module Telemetry
        NAMESPACE = "civisibility"

        METRIC_EVENT_CREATED = "event_created"
        METRIC_EVENT_FINISHED = "event_finished"

        METRIC_MANUAL_API_EVENTS = "manual_api_events"

        METRIC_EVENTS_ENQUEUED = "events_enqueued_for_serialization"
        METRIC_ENDPOINT_PAYLOAD_REQUESTS = "endpoint_payload.requests"
        METRIC_ENDPOINT_PAYLOAD_REQUESTS_MS = "endpoint_payload.requests_ms"
        METRIC_ENDPOINT_PAYLOAD_REQUESTS_ERRORS = "endpoint_payload.requests_errors"
        METRIC_ENDPOINT_PAYLOAD_BYTES = "endpoint_payload.bytes"
        METRIC_ENDPOINT_PAYLOAD_EVENTS_COUNT = "endpoint_payload.events_count"
        METRIC_ENDPOINT_PAYLOAD_EVENTS_SERIALIZATION_MS = "endpoint_payload.events_serialization_ms"
        METRIC_ENDPOINT_PAYLOAD_DROPPED = "endpoint_payload.dropped"

        METRIC_GIT_COMMAND = "git.command"
        METRIC_GIT_COMMAND_ERRORS = "git.command_errors"
        METRIC_GIT_COMMAND_MS = "git.command_ms"

        METRIC_GIT_REQUESTS_SEARCH_COMMITS = "git_requests.search_commits"
        METRIC_GIT_REQUESTS_SEARCH_COMMITS_MS = "git_requests.search_commits_ms"
        METRIC_GIT_REQUESTS_SEARCH_COMMITS_ERRORS = "git_requests.search_commits_errors"

        METRIC_GIT_REQUESTS_OBJECT_PACK = "git_requests.objects_pack"
        METRIC_GIT_REQUESTS_OBJECT_PACK_MS = "git_requests.objects_pack_ms"
        METRIC_GIT_REQUESTS_OBJECT_PACK_ERRORS = "git_requests.objects_pack_errors"
        METRIC_GIT_REQUESTS_OBJECT_PACK_BYTES = "git_requests.objects_pack_bytes"
        METRIC_GIT_REQUESTS_OBJECT_PACK_FILES = "git_requests.objects_pack_files"

        METRIC_GIT_REQUESTS_SETTINGS = "git_requests.settings"
        METRIC_GIT_REQUESTS_SETTINGS_MS = "git_requests.settings_ms"
        METRIC_GIT_REQUESTS_SETTINGS_ERRORS = "git_requests.settings_errors"
        METRIC_GIT_REQUESTS_SETTINGS_RESPONSE = "git_requests.settings_response"

        METRIC_ITR_SKIPPABLE_TESTS_REQUEST = "itr_skippable_tests.request"
        METRIC_ITR_SKIPPABLE_TESTS_REQUEST_MS = "itr_skippable_tests.request_ms"
        METRIC_ITR_SKIPPABLE_TESTS_REQUEST_ERRORS = "itr_skippable_tests.request_errors"
        METRIC_ITR_SKIPPABLE_TESTS_RESPONSE_BYTES = "itr_skippable_tests.response_bytes"
        METRIC_ITR_SKIPPABLE_TESTS_RESPONSE_TESTS = "itr_skippable_tests.response_tests"

        METRIC_ITR_SKIPPED = "itr_skipped"
        METRIC_ITR_UNSKIPPABLE = "itr_unskippable"
        METRIC_ITR_FORCED_RUN = "itr_forced_run"

        METRIC_CODE_COVERAGE_STARTED = "code_coverage_started"
        METRIC_CODE_COVERAGE_FINISHED = "code_coverage_finished"
        METRIC_CODE_COVERAGE_IS_EMPTY = "code_coverage.is_empty"
        METRIC_CODE_COVERAGE_FILES = "code_coverage.files"
        METRIC_CODE_COVERAGE_ERRORS = "code_coverage.errors"

        METRIC_TEST_SESSION = "test_session"

        TAG_TEST_FRAMEWORK = "test_framework"
        TAG_EVENT_TYPE = "event_type"
        TAG_HAS_CODEOWNER = "has_codeowner"
        TAG_IS_UNSUPPORTED_CI = "is_unsupported_ci"
        TAG_BROWSER_DRIVER = "browser_driver"
        TAG_IS_RUM = "is_rum"
        TAG_LIBRARY = "library"
        TAG_ENDPOINT = "endpoint"
        TAG_ERROR_TYPE = "error_type"
        TAG_EXIT_CODE = "exit_code"
        TAG_STATUS_CODE = "status_code"
        TAG_REQUEST_COMPRESSED = "rq_compressed"
        TAG_RESPONSE_COMPRESSED = "rs_compressed"
        TAG_COMMAND = "command"
        TAG_COVERAGE_ENABLED = "coverage_enabled"
        TAG_ITR_ENABLED = "itr_enabled"
        TAG_ITR_SKIP_ENABLED = "itr_skip_enabled"
        TAG_REQUIRE_GIT = "require_git"
        TAG_PROVIDER = "provider"
        TAG_AUTO_INJECTED = "auto_injected"

        module EventType
          TEST = "test"
          SUITE = "suite"
          MODULE = "module"
          SESSION = "session"
        end

        module Library
          CUSTOM = "custom"
        end

        module Endpoint
          CODE_COVERAGE = "code_coverage"
          TEST_CYCLE = "test_cycle"
        end

        module ErrorType
          NETWORK = "network"
          TIMEOUT = "timeout"
          STATUS_CODE = "status_code"
        end

        module ExitCode
          MISSING = "missing"
        end

        module Command
          GET_REPOSITORY = "get_repository"
          GET_BRANCH = "get_branch"
          CHECK_SHALLOW = "check_shallow"
          UNSHALLOW = "unshallow"
          GET_LOCAL_COMMITS = "get_local_commits"
          GET_OBJECTS = "get_objects"
          PACK_OBJECTS = "pack_objects"
        end
      end
    end
  end
end
