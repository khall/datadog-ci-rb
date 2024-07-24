# frozen_string_literal: true

SpiedMetric = Struct.new(:name, :value, :tags)

# no-dd-sa:ruby-best-practices/top-level-methods
def telemetry_spy_value_suffix(value)
  return "" if value.nil?
  " with value = [#{value}]"
end

# spy on telemetry metrics emitted
RSpec.shared_context "Telemetry spy" do
  before do
    @metrics = {}

    allow(Datadog::CI::Utils::Telemetry).to receive(:inc) do |metric_name, count, tags|
      @metrics[:inc] ||= []
      @metrics[:inc] << SpiedMetric.new(metric_name, count, tags)
    end

    allow(Datadog::CI::Utils::Telemetry).to receive(:distribution) do |metric_name, value, tags|
      @metrics[:distribution] ||= []
      @metrics[:distribution] << SpiedMetric.new(metric_name, value, tags)
    end
  end

  shared_examples_for "emits telemetry metric" do |metric_type, metric_name, value = nil|
    it "emits :#{metric_type} metric #{metric_name}#{telemetry_spy_value_suffix(value)}" do
      subject

      metric = telemetry_metric(metric_type, metric_name)
      expect(metric).not_to be_nil

      if value
        expect(metric.value).to eq(value)
      end
    end
  end

  def telemetry_metric(type, name)
    @metrics[type].find { |m| m.name == name }
  end
end
