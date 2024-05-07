require "knapsack_pro"
require "fileutils"

RSpec.describe "RSpec instrumentation with Knapsack Pro runner in queue mode" do
  before { skip("jruby fails on file with emojis in name") if PlatformHelpers.jruby? }

  include_context "CI mode activated" do
    let(:integration_name) { :rspec }
  end

  before do
    allow_any_instance_of(KnapsackPro::Runners::Queue::RSpecRunner).to receive(:test_file_paths).and_return(
      ["./spec/datadog/ci/contrib/knapsack_rspec/suite_under_test/some_test_rspec.rb"],
      []
    )
  end

  # Yields to a block in a new RSpec global context. All RSpec
  # test configuration and execution should be wrapped in this method.
  def with_new_rspec_environment
    old_configuration = ::RSpec.configuration
    old_world = ::RSpec.world
    ::RSpec.configuration = ::RSpec::Core::Configuration.new
    ::RSpec.world = ::RSpec::Core::World.new

    yield
  ensure
    ::RSpec.configuration = old_configuration
    ::RSpec.world = old_world
  end

  def devnull
    File.new("/dev/null", "w")
  end

  it "instruments this rspec session" do
    with_new_rspec_environment do
      ClimateControl.modify(
        "KNAPSACK_PRO_CI_NODE_BUILD_ID" => "142",
        "KNAPSACK_PRO_TEST_SUITE_TOKEN_RSPEC" => "example_token",
        "KNAPSACK_PRO_FIXED_QUEUE_SPLIT" => "true"
      ) do
        KnapsackPro::Adapters::RSpecAdapter.bind
        KnapsackPro::Runners::Queue::RSpecRunner.run("", devnull, devnull)
      rescue ArgumentError
        # suppress invalid API key error
      end
    end

    # test session and module traced
    expect(test_session_span).not_to be_nil
    expect(test_module_span).not_to be_nil

    # test session and module are failed
    expect([test_session_span, test_module_span]).to all have_fail_status

    # single test suite span
    expect(test_suite_spans).to have(1).item
    expect(test_suite_spans.first).to have_test_tag(:status, Datadog::CI::Ext::Test::Status::FAIL)
    expect(test_suite_spans.first).to have_test_tag(
      :suite,
      "SomeTest at ./spec/datadog/ci/contrib/knapsack_rspec/suite_under_test/some_test_rspec.rb"
    )

    # there is test span for every test case
    expect(test_spans).to have(2).items
    # test spans belong to a single test suite
    expect(test_spans).to have_unique_tag_values_count(:test_suite_id, 1)
    expect(test_spans).to have_tag_values_no_order(
      :status,
      [Datadog::CI::Ext::Test::Status::FAIL, Datadog::CI::Ext::Test::Status::PASS]
    )

    # every test span is connected to test module and test session
    expect(test_spans).to all have_test_tag(:test_module_id)
    expect(test_spans).to all have_test_tag(:test_session_id)
  end
end
