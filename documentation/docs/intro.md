---
sidebar_position: 1
title: Overview
description: Smartest is a small Ruby test runner built around explicit keyword fixtures.
---

# Smartest

Smartest is a small Ruby test runner with a keyword-fixture-first design.

It is designed around three ideas:

- Tests should read naturally at the top level.
- Fixture usage should be explicit in the test signature.
- Teardown should be written only for fixtures that actually need it.

```ruby
test("factorial") do
  expect(1 * 2 * 3).to eq(6)
end
```

Fixture-driven tests use required Ruby keyword arguments:

```ruby
test("GET /me") do |logged_in_client:|
  response = logged_in_client.get("/me")

  expect(response.status).to eq(200)
end
```

## What to Read First

- [Getting Started](./getting-started.md) shows the smallest runnable test file.
- [Writing Tests](./writing-tests.md) explains test structure and expectations.
- [Running Test Suites](./running-test-suites.md) covers autorun and the CLI.
- [Fixtures](./fixtures.md) explains class-based fixtures, dependencies, and cleanup.
- [Browser Tests With Playwright](./playwright-browser-tests.md) shows how to use fixtures for browser tests.

## Current Scope

Smartest currently focuses on the MVP runner:

- top-level `test`
- class-based fixtures
- keyword-argument fixture injection
- fixture dependencies through keyword arguments
- fixture cleanup
- suite-scoped fixtures through `suite_fixture`
- suite hooks through `around_suite`
- test hooks through `around_test`
- console reporting
- a CLI runner

Nested `describe` blocks, watch mode, parallel execution, and file-scoped fixtures are not part of the current MVP.
