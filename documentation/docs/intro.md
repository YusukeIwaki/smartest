---
title: Pytest-style fixtures for Ruby
description: Smartest is a Ruby test runner with pytest-style fixture injection, explicit fixture dependencies, and cleanup.
---

# Smartest

introduces **Pytest-style fixtures for Ruby.**

Smartest is a small Ruby test runner that brings pytest-style fixture
injection, explicit fixture dependencies, and fixture cleanup to Ruby tests.

It is designed around three ideas:

- Tests should read naturally at the top level.
- Fixture usage should be explicit in the test signature.
- Teardown should be written only for fixtures that actually need it.

```ruby
# smartest/fixtures/web_fixture.rb
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    cleanup { server.stop }
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end

# smartest/test_helper.rb
around_suite do |suite|
  use_fixture WebFixture
  suite.run
end

# smartest/web_test.rb
test("GET /health") do |client:|
  response = client.get("/health")

  expect(response.status).to eq(200)
end
```

## What to Read First

- [Getting Started](./getting-started.md) shows the smallest runnable test file.
- [Writing Tests](./writing-tests.md) explains test structure and expectations.
- [Skipping Tests](./skipping-tests.md) covers skipped tests and expected failures.
- [Running Test Suites](./running-test-suites.md) covers autorun and the CLI.
- [Fixtures](./fixtures.md) explains class-based fixtures, dependencies, and cleanup.
- [Stubs](./stubs.md) shows method stubs that reset from fixture cleanup.
- [Helpers](./helpers.md) explains registering helper modules from `around_test`.
- [Browser Tests With Playwright](./playwright-browser-tests.md) shows how to use fixtures for browser tests.

## Current Scope

Smartest currently focuses on a small runner API:

- top-level `test`
- class-based fixtures
- keyword-argument fixture injection
- fixture dependencies through keyword arguments
- fixture cleanup
- suite-scoped fixtures through `suite_fixture`
- fixture-scoped method and constant stubs
- suite hooks through `around_suite`
- test hooks through `around_test`
- skipped and pending tests through `skip` and `pending`
- expectation matchers through `expect`
- console reporting
- a CLI runner

Nested `describe` blocks, watch mode, parallel execution, and file-scoped fixtures are not part of the current MVP.
