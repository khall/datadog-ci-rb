require "rspec/queue"
require "fileutils"

RSpec.describe "RSpec instrumentation with Shopify's ci-queue runner" do
  include_context "CI mode activated" do
    let(:integration_name) { :rspec }
  end

  let(:run_id) { rand(1..2**64 - 1) }
  let(:options) do
    RSpec::Core::ConfigurationOptions.new([
      "-Ispec/datadog/ci/contrib/ci_queue_rspec/suite_under_test",
      "--queue",
      "list:.%2Fspec%2Fdatadog%2Fci%2Fcontrib%2Fci_queue_rspec%2Fsuite_under_test%2Fsome_test_rspec.rb%5B1%3A1%3A1%5D:.%2Fspec%2Fdatadog%2Fci%2Fcontrib%2Fci_queue_rspec%2Fsuite_under_test%2Fsome_test_rspec.rb%5B1%3A1%3A2%5D",
      "--require",
      "some_test_rspec.rb",
      "--build",
      run_id.to_s,
      "--worker",
      "1",
      "--default-path",
      "spec/datadog/ci/contrib/ci_queue_rspec/suite_under_test"
    ])
  end

  before do
    FileUtils.mkdir("log")
  end

  after do
    FileUtils.rm_rf("log")
  end

  def devnull
    File.new("/dev/null", "w")
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

  it "instruments this rspec session" do
    with_new_rspec_environment do
      ::RSpec::Queue::Runner.new(options).run(devnull, devnull)
    end

    # test session and module traced
    expect(test_session_span).not_to be_nil
    expect(test_module_span).not_to be_nil

    # test session and module are failed
    expect([test_session_span, test_module_span]).to all have_fail_status

    # test suite spans are created for each test as for parallel execution
    expect(test_suite_spans).to have(2).items
    expect(test_suite_spans).to have_tag_values_no_order(
      :status,
      [Datadog::CI::Ext::Test::Status::FAIL, Datadog::CI::Ext::Test::Status::PASS]
    )
    expect(test_suite_spans).to have_tag_values_no_order(
      :suite,
      [
        "SomeTest at ./spec/datadog/ci/contrib/ci_queue_rspec/suite_under_test/some_test_rspec.rb (ci-queue running example [nested fails])",
        "SomeTest at ./spec/datadog/ci/contrib/ci_queue_rspec/suite_under_test/some_test_rspec.rb (ci-queue running example [nested foo])"
      ]
    )

    # there is test span for every test case
    expect(test_spans).to have(2).items
    # each test span has its own test suite
    expect(test_spans).to have_unique_tag_values_count(:test_suite_id, 2)

    # every test span is connected to test module and test session
    expect(test_spans).to all have_test_tag(:test_module_id)
    expect(test_spans).to all have_test_tag(:test_session_id)
  end
end