# frozen_string_literal: true

require "json"

require_relative "span"
require_relative "utils/test_run"

module Datadog
  module CI
    # Represents a single part of a test run.
    #
    # @public_api
    class Test < Span
      # @return [String] the name of the test.
      def name
        get_tag(Ext::Test::TAG_NAME)
      end

      # Finishes the current test.
      # @return [void]
      def finish
        recorder.deactivate_test

        super
      end

      # Running test suite that this test is part of (if any).
      # @return [Datadog::CI::TestSuite] the test suite this test belongs to
      # @return [nil] if the test suite is not found
      def test_suite
        suite_name = test_suite_name
        CI.active_test_suite(suite_name) if suite_name
      end

      # Span id of the running test suite this test belongs to.
      # @return [String] the span id of the test suite.
      def test_suite_id
        get_tag(Ext::Test::TAG_TEST_SUITE_ID)
      end

      # Name of the running test suite this test belongs to.
      # @return [String] the name of the test suite.
      def test_suite_name
        get_tag(Ext::Test::TAG_SUITE)
      end

      # Span id of the running test module this test belongs to.
      # @return [String] the span id of the test module.
      def test_module_id
        get_tag(Ext::Test::TAG_TEST_MODULE_ID)
      end

      # Span id of the running test session this test belongs to.
      # @return [String] the span id of the test session.
      def test_session_id
        get_tag(Ext::Test::TAG_TEST_SESSION_ID)
      end

      # Source file path of the test relative to git repository root.
      # @return [String] the source file path of the test
      # @return [nil] if the source file path is not found
      def source_file
        get_tag(Ext::Test::TAG_SOURCE_FILE)
      end

      # Returns "true" if the test is skipped by the intelligent test runner.
      # @return [Boolean] true if the test is skipped by the intelligent test runner, false otherwise.
      def skipped_by_itr?
        get_tag(Ext::Test::TAG_ITR_SKIPPED_BY_ITR) == "true"
      end

      # Sets the status of the span to "pass".
      # @return [void]
      def passed!
        super

        record_test_result(Ext::Test::Status::PASS)
      end

      # Sets the status of the span to "fail".
      # @param [Exception] exception the exception that caused the test to fail.
      # @return [void]
      def failed!(exception: nil)
        super

        record_test_result(Ext::Test::Status::FAIL)
      end

      # Sets the status of the span to "skip".
      # @param [Exception] exception the exception that caused the test to fail.
      # @param [String] reason the reason why the test was skipped.
      # @return [void]
      def skipped!(exception: nil, reason: nil)
        super

        record_test_result(Ext::Test::Status::SKIP)
      end

      # Sets the parameters for this test (e.g. Cucumber example or RSpec specs).
      # Parameters are needed to compute test fingerprint to distinguish between different tests having same names.
      #
      # @param [Hash] arguments the arguments that test accepts as key-value hash
      # @param [Hash] metadata optional metadata
      # @return [void]
      def set_parameters(arguments, metadata = {})
        return if arguments.nil?

        set_tag(Ext::Test::TAG_PARAMETERS, Utils::TestRun.test_parameters(arguments: arguments, metadata: metadata))
      end

      # Gets the parameters for this test (e.g. Cucumber example or RSpec specs) as a serialized JSON.
      #
      # @return [String] the serialized JSON of the parameters
      # @return [nil] if this test does not have parameters
      def parameters
        get_tag(Ext::Test::TAG_PARAMETERS)
      end

      private

      def record_test_result(datadog_status)
        test_suite&.record_test_result(datadog_status)
      end
    end
  end
end
