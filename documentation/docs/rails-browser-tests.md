---
title: Rails Browser Tests
description: Write local Rails system tests with Playwright and explicit fixtures.
---

# Rails Browser Tests

Smartest can scaffold a Rails browser-test setup for local Rails system tests:

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

## Positioning

Smartest's Rails integration is for writing local Rails system tests with
Playwright and explicit keyword fixtures. It keeps the Rails-native strengths of
system tests: FactoryBot, ActiveRecord records, Rails helpers, mailers, jobs,
method stubs, and local app state can all be created from Ruby fixture code.

Use Smartest when the test should run against the Rails `test` environment and
when setup should be visible from the test signature:

```ruby
test("suspended user sees account restriction page") do |suspended_user_page:|
  suspended_user_page.goto("/dashboard")
end
```

Smartest is not a Capybara compatibility layer. It does not provide Capybara
DSL methods such as `visit`, `fill_in`, or `assert_selector`; browser code uses
Playwright locators and Playwright web-first assertions.

Smartest is also not the main choice for staging or production-like E2E suites.
If the suite targets a deployed environment, needs Playwright trace/report
workflows, parallel workers, and browser/project matrices, use Node.js
Playwright Test.

## Test Server

The generated Rails fixture starts `Rails.application` with
`Smartest::Rails::TestServer`:

```ruby
# frozen_string_literal: true

require 'smartest/rails'
require "playwright"

class RailsSystemTestFixture < Smartest::Fixture
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
class RailsSystemTestFixture < Smartest::Fixture
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

## Stateful Page Fixtures

Rails tests are often clearer when user state, browser page, and stubs are
combined into a named page fixture. The test can then request `admin_page:`,
`suspended_user_page:`, or `page_with_push_stubbed:` instead of hiding setup in a
helper or `before` block.

```ruby
class ApplicationSystemFixture < Smartest::Fixture
  fixture :admin_user do
    create(:user, :admin)
  end

  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :admin_page do |page:, admin_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) { admin_user }
    page
  end

  fixture :suspended_user_page do |page:, suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) { suspended_user }
    page
  end

  fixture :page_with_push_stubbed do |page:|
    simple_stub(PushNotifier, :deliver_later) { :stubbed }
    page
  end
end
```

Register the fixture class from `around_suite`:

```ruby
around_suite do |suite|
  use_fixture RailsSystemTestFixture
  use_fixture ApplicationSystemFixture
  use_matcher PlaywrightMatcher
  suite.run
end
```

Tests request the page state they need:

```ruby
test("admin opens the user management page") do |admin_page:|
  admin_page.goto("/admin/users")

  expect(admin_page.get_by_role("heading", name: "Users")).to be_visible
end

test("suspended user sees account restriction page") do |suspended_user_page:|
  suspended_user_page.goto("/dashboard")

  expect(
    suspended_user_page.get_by_role("heading", name: "Your account is suspended")
  ).to be_visible
end

test("push failure banner is not shown when push is stubbed") do |page_with_push_stubbed:|
  page_with_push_stubbed.goto("/settings/notifications")

  expect(page_with_push_stubbed.get_by_text("Push failed")).not_to be_visible
end
```

## Database Cleanup

The generated Rails fixture sets `RAILS_ENV=test` before loading
`config/environment`. Prepare the test database before running Smartest, just as
you would for Rails tests:

```bash
bin/rails db:test:prepare
bundle exec smartest smartest/example_rails_system_test.rb
```

When using DatabaseCleaner, run an initial truncation at suite startup and wrap
each test in transaction cleaning:

```ruby
require "database_cleaner/active_record"

around_suite do |suite|
  DatabaseCleaner[:active_record].clean_with(:truncation)

  around_test do |test|
    DatabaseCleaner[:active_record].strategy = :transaction
    DatabaseCleaner[:active_record].cleaning do
      test.run
    end
  end

  use_fixture RailsSystemTestFixture
  use_matcher PlaywrightMatcher
  suite.run
end
```

This `around_test` hook wraps fixture setup, the test body, and fixture teardown.
If records created by Smartest fixtures are not visible from the browser request
in your app, switch the per-test strategy to truncation or another
application-specific strategy.

Keep Rails browser tests serial by default. For parallel execution, run each
worker in a separate Ruby process with its own database and Rails test server.
Smartest does not provide automatic database separation between parallel
workers.

## Small Example

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
