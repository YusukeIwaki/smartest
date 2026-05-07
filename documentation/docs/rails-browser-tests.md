---
title: Rails Browser Tests
description: Start a same-process Rails test server and drive it with Playwright fixtures.
---

# Rails Browser Tests

Smartest can scaffold a Rails browser-test setup:

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

## Test Server

The generated Rails fixture starts `Rails.application` with
`Smartest::Rails::TestServer`:

```ruby
# frozen_string_literal: true

require 'smartest/rails'
require "playwright"

class RailsSystemFixture < Smartest::Fixture
  suite_fixture :rails_server do
    # Set the environment before loading config/environment so the test
    # server cannot boot against the development database by default.
    ENV["RAILS_ENV"] ||= "test"
    ENV["RACK_ENV"] ||= ENV["RAILS_ENV"]
    require_relative "../../config/environment"

    server = Smartest::Rails::TestServer.new(app: Rails.application)
    server.start
    server.wait_for_ready

    on_teardown do
      server.stop
      server.wait_for_stopped
    end

    server
  end
end
```

`Smartest::Rails::TestServer` is only loaded when `smartest/rails` is required
explicitly. Plain `require "smartest"` does not load Puma.

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

The `rails_server` fixture sets `RAILS_ENV` and `RACK_ENV` before requiring
`config/environment`, then starts the Rails app in the same Ruby process as the
test runner. Setting `RAILS_ENV` first prevents the server from accidentally
booting in development mode and touching the development database.

## Port Selection

Set `SMARTEST_RAILS_PORT` when you need a fixed Rails test server port:

```bash
SMARTEST_RAILS_PORT=4001 bundle exec smartest smartest/example_rails_system_test.rb
```

When the environment variable is not set, the test server asks the OS for an
available port by binding Puma to port `0`.

## Method Stubs

Rails browser tests often need stubs applied in fixture setup to affect code
that runs inside the Rails server thread. Smartest method stubs are process-wide,
so stubs installed by fixtures are visible to the same-process Rails server
thread.

Keep these tests serial inside one Ruby process. Smartest stubs do not provide
isolation for multi-threaded parallel test execution; one test can observe or
reset another test's method or constant stub.

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
