# Datadog CI Visibility for Ruby

[![Gem Version](https://badge.fury.io/rb/datadog-ci.svg)](https://badge.fury.io/rb/datadog-ci)
[![YARD documentation](https://img.shields.io/badge/YARD-documentation-blue)](https://datadoghq.dev/datadog-ci-rb/)
[![codecov](https://codecov.io/gh/DataDog/datadog-ci-rb/branch/main/graph/badge.svg)](https://app.codecov.io/gh/DataDog/datadog-ci-rb/branch/main)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/DataDog/datadog-ci-rb/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/DataDog/datadog-ci-rb/tree/main)

Datadog's Ruby Library for instrumenting your tests.
Learn more on our [official website](https://docs.datadoghq.com/tests/) and check out our [documentation for this library](https://docs.datadoghq.com/tests/setup/ruby/?tab=cloudciprovideragentless).

## Features

- [Test Visibility](https://docs.datadoghq.com/tests/) - collect metrics and results for your tests
- [Intelligent test runner](https://docs.datadoghq.com/intelligent_test_runner/) - save time by selectively running only tests affected by code changes
- [Search and manage CI tests](https://docs.datadoghq.com/tests/search/)
- [Enhance developer workflows](https://docs.datadoghq.com/tests/developer_workflows)
- [Flaky test management](https://docs.datadoghq.com/tests/guides/flaky_test_management/)
- [Add custom measures to your tests](https://docs.datadoghq.com/tests/guides/add_custom_measures/?tab=ruby)
- [Browser tests integration with Datadog RUM](https://docs.datadoghq.com/tests/browser_tests)

## Installation

Add to your Gemfile.

```ruby
group :test do
  gem "datadog-ci"
end
```

## Upgrade from ddtrace v1.x

If you used [test visibility for Ruby](https://docs.datadoghq.com/tests/setup/ruby/) with [ddtrace](https://github.com/datadog/dd-trace-rb) gem, check out our [upgrade guide](/docs/UpgradeGuide.md).

## Setup

- [Test visibility setup](https://docs.datadoghq.com/tests/setup/ruby/?tab=cloudciprovideragentless)
- [Intelligent test runner setup](https://docs.datadoghq.com/intelligent_test_runner/setup/ruby) (test visibility setup is required before setting up intelligent test runner)

## Contributing

See [development guide](/docs/DevelopmentGuide.md), [static typing guide](docs/StaticTypingGuide.md) and [contributing guidelines](/CONTRIBUTING.md).

## Code of Conduct

Everyone interacting in the `Datadog::CI` project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](/CODE_OF_CONDUCT.md).
