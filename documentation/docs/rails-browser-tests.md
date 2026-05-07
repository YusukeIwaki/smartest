---
title: Rails Browser Tests
description: Start a same-process Rails test server and drive it with Playwright fixtures.
---

# Rails Browser Tests

Smartest can scaffold a small Rails browser-test setup:

```bash
bundle exec smartest --init-rails
```

The generated scaffold creates:

```text
smartest/fixtures/rails_system_fixture.rb
smartest/matchers/playwright_matcher.rb
smartest/example_rails_system_test.rb
```

It also adds `playwright-ruby-client` to the Gemfile test group, installs the
Playwright npm package, and downloads browsers.

## Fixture Structure

The generated Rails fixture keeps these resources suite-scoped:

- `rails_server`
- `base_url`
- `playwright`
- `browser`

Each test gets its own browser context and page:

```ruby
class RailsSystemFixture < Smartest::Fixture
  fixture :browser_context do |base_url:, browser:|
    context = browser.new_context(baseURL: base_url)
    on_teardown { context.close }
    context
  end

  fixture :page do |browser_context:|
    page = browser_context.new_page
    on_teardown { page.close }
    page
  end
end
```

The `rails_server` fixture sets `RAILS_ENV` and `RACK_ENV` to `test` when they
are not already set, requires `config/environment`, and starts
`Rails.application` with Puma in the same Ruby process as the test runner.

## Port Selection

Set `SMARTEST_RAILS_PORT` when you need a fixed Rails test server port:

```bash
SMARTEST_RAILS_PORT=4001 bundle exec smartest smartest/example_rails_system_test.rb
```

When the environment variable is not set, the generated server asks the OS for
an available port by binding Puma to port `0`.

## Shared Method Stubs

Rails browser tests often need stubs applied in fixture setup to affect code
that runs inside the Rails server thread. Smartest automatically gives each test
case a process-shared `SimpleStub` store. That makes method stubs installed by
fixtures visible to the same-process Rails server thread without adding any
store setup to `smartest/test_helper.rb`.

If Smartest runs tests concurrently in one Ruby process in the future, tests
using this process-shared method stub store are serialized internally while the
test store is active. This avoids one test's Rails server thread reading another
test's stubs.

## Example

```ruby
class EdgeCaseFixture < Smartest::Fixture
  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :suspended_user_page do |page:, suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) { suspended_user }
    page
  end
end
```

```ruby
test("suspended user sees account restriction page") do |suspended_user_page:|
  suspended_user_page.goto("/dashboard")

  expect(
    suspended_user_page.get_by_role("heading", name: "Your account is suspended")
  ).to be_visible
end
```
