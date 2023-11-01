require "datadog/tracing"

# For contrib, we only allow one tracer to be active:
# the global tracer in +Datadog::Tracing+.
module TracerHelpers
  # Returns the current tracer instance
  def tracer
    Datadog::Tracing.send(:tracer)
  end

  def produce_test_trace(
    framework: "rspec", operation: "rspec.example",
    test_name: "test_add", test_suite: "calculator_tests",
    service: "rspec-test-suite", result: "PASSED", exception: nil,
    start_time: Time.now, duration_seconds: 2,
    with_http_span: false
  )
    # each time monotonic clock is called it will return a number that is
    # by `duration_seconds` bigger than the previous
    allow(Process).to receive(:clock_gettime).and_return(
      0, duration_seconds, 2 * duration_seconds, 3 * duration_seconds
    )
    Timecop.freeze(start_time)

    Datadog::CI.trace_test(
      test_name,
      tags: {
        framework: framework,
        framework_version: "1.0.0",
        test_type: "test",
        test_suite: test_suite
      },
      service_name: service,
      operation_name: operation
    ) do |test|
      if with_http_span
        Datadog::Tracing.trace("http-call", type: "http", service: "net-http") do |span, trace|
          span.set_tag("custom_tag", "custom_tag_value")
          span.set_metric("custom_metric", 42)
        end
      end

      Datadog::Tracing.active_span.set_tag("test_owner", "my_team")
      Datadog::Tracing.active_span.set_metric("memory_allocations", 16)

      case result
      when "FAILED"
        test.failed!(exception)
      when "SKIPPED"
        test.skipped!(exception)
      else
        test.passed!
      end

      Timecop.travel(start_time + duration_seconds)
    end

    Timecop.return
  end

  def first_test_span
    spans.find { |span| span.type == "test" }
  end

  def first_other_span
    spans.find { |span| span.type != "test" }
  end

  # Returns spans and caches it (similar to +let(:spans)+).
  def traces
    @traces ||= fetch_traces
  end

  # Returns spans and caches it (similar to +let(:spans)+).
  def spans
    @spans ||= fetch_spans
  end

  # Returns the only trace in the current tracer writer.
  #
  # This method will not allow for ambiguous use,
  # meaning it will throw an error when more than
  # one span is available.
  def trace
    @trace ||= begin
      expect(traces).to have(1).item, "Requested the only trace, but #{traces.size} traces are available"
      traces.first
    end
  end

  # Returns the only span in the current tracer writer.
  #
  # This method will not allow for ambiguous use,
  # meaning it will throw an error when more than
  # one span is available.
  def span
    @span ||= begin
      expect(spans).to have(1).item, "Requested the only span, but #{spans.size} spans are available"
      spans.first
    end
  end

  # Retrieves all traces in the current tracer instance.
  # This method does not cache its results.
  def fetch_traces(tracer = self.tracer)
    tracer.instance_variable_get(:@traces) || []
  end

  # Retrieves and sorts all spans in the current tracer instance.
  # This method does not cache its results.
  def fetch_spans(tracer = self.tracer)
    traces = fetch_traces(tracer)
    traces.collect(&:spans).flatten.sort! do |a, b|
      if a.name == b.name
        if a.resource == b.resource
          if a.start_time == b.start_time
            a.end_time <=> b.end_time
          else
            a.start_time <=> b.start_time
          end
        else
          a.resource <=> b.resource
        end
      else
        a.name <=> b.name
      end
    end
  end

  # Remove all traces from the current tracer instance and
  # busts cache of +#spans+ and +#span+.
  def clear_traces!
    tracer.instance_variable_set(:@traces, [])

    @traces = nil
    @trace = nil
    @spans = nil
    @span = nil
  end

  RSpec.configure do |config|
    # Capture spans from the global tracer
    config.before do
      # DEV `*_any_instance_of` has concurrency issues when running with parallelism (e.g. JRuby).
      # DEV Single object `allow` and `expect` work as intended with parallelism.
      allow(Datadog::Tracing::Tracer).to receive(:new).and_wrap_original do |method, **args, &block|
        instance = method.call(**args, &block)

        # The mutex must be eagerly initialized to prevent race conditions on lazy initialization
        write_lock = Mutex.new
        allow(instance).to receive(:write) do |trace|
          instance.instance_exec do
            write_lock.synchronize do
              @traces ||= []
              @traces << trace
            end
          end
        end

        instance
      end
    end

    # Execute shutdown! after the test has finished
    # teardown and mock verifications.
    #
    # Changing this to `config.after(:each)` would
    # put shutdown! inside the test scope, interfering
    # with mock assertions.
    config.around do |example|
      example.run.tap do
        Datadog::Tracing.shutdown!
      end
    end
  end

  # Useful for integration testing.
  def use_real_tracer!
    @use_real_tracer = true
    allow(Datadog::Tracing::Tracer).to receive(:new).and_call_original
  end
end
