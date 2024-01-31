require "minitest/queue/runner"
require "fileutils"

RSpec.describe "Minitest instrumentation with Shopify's ci-queue runner" do
  include_context "CI mode activated" do
    let(:integration_name) { :minitest }
    let(:integration_options) { {service_name: "ltest"} }
  end

  let(:run_id) { rand(1..2**64 - 1) }

  before do
    Minitest::Runnable.reset
    FileUtils.mkdir("log")

    Minitest::Queue::Runner.invoke(
      [
        "-Ispec/datadog/ci/contrib/ci_queue_minitest",
        "--build",
        run_id.to_s,
        "--worker",
        "1",
        "--queue",
        "list:SomeTest%23test_pass:SomeTest%23test_pass_other:SomeTest%23test_fail",
        "run",
        "spec/datadog/ci/contrib/ci_queue_minitest/fake_test.rb"
      ]
    )

    Minitest.run([])
  end

  after do
    FileUtils.rm_rf("log")
  end

  it "instruments this minitest session" do
    # test session and module traced
    expect(test_session_span).not_to be_nil
    expect(test_module_span).not_to be_nil

    # test session and module are failed
    expect([test_session_span, test_module_span]).to all have_fail_status

    # test suite spans are created for each test as for parallel execution
    expect(test_suite_spans).to have(3).items
    expect(test_suite_spans).to have_tag_values_no_order(:status, ["pass", "pass", "fail"])
    expect(test_suite_spans).to have_tag_values_no_order(
      :suite,
      [
        "SomeTest at spec/datadog/ci/contrib/ci_queue_minitest/fake_test.rb (test_fail concurrently)",
        "SomeTest at spec/datadog/ci/contrib/ci_queue_minitest/fake_test.rb (test_pass concurrently)",
        "SomeTest at spec/datadog/ci/contrib/ci_queue_minitest/fake_test.rb (test_pass_other concurrently)"
      ]
    )

    # there is test span for every test case
    expect(test_spans).to have(3).items
    # each test span has its own test suite
    expect(test_spans).to have_unique_tag_values_count(:test_suite_id, 3)

    # every test span is connected to test module and test session
    expect(test_spans).to all have_test_tag(:test_module_id)
    expect(test_spans).to all have_test_tag(:test_session_id)
  end
end
