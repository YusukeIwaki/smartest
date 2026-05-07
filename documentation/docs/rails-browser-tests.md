---
title: Rails Browser Tests
sidebar_label: Rails
description: Write Rails system tests with Playwright and explicit Smartest fixtures.
---

# Rails Browser Tests

Smartest can run Rails browser tests against your Rails `test` environment.

It is useful when you want the Rails-native power of system tests -- FactoryBot,
ActiveRecord records, Rails helpers, mailers, jobs, method stubs, and local app
state -- while writing browser interactions with Playwright locators and
web-first assertions.

```bash
bundle exec smartest --init-rails
bin/rails db:test:prepare
bundle exec smartest smartest/example_rails_system_test.rb
```

The generated setup starts your Rails application as a test server, creates a
Playwright browser page, and lets each test request the setup it needs through
keyword fixtures.

```ruby
test("suspended user sees account restriction page") do |suspended_user_page:|
  suspended_user_page.goto("/dashboard")

  expect(
    suspended_user_page.get_by_role("heading", name: "Your account is suspended")
  ).to be_visible
end
```

## When to use Smartest with Rails

Use Smartest when you want to build test state from Ruby and verify the result
through a real browser.

| Use case | Recommendation |
| --- | --- |
| You want the simplest Rails-default system test setup | Rails system test + Capybara |
| Your app already uses RSpec system specs heavily | RSpec system spec |
| You want to test a deployed staging or production-like environment | Node.js Playwright Test |
| You want to create Rails test state with FactoryBot, ActiveRecord, stubs, jobs, or mailers, then verify it with Playwright | Smartest |
| You want to keep using Capybara DSL such as `visit`, `fill_in`, or `assert_selector` | Capybara |
| You want to use Playwright APIs directly from Ruby | Smartest + `playwright-ruby-client` |

Smartest is not a Capybara compatibility layer. Browser code uses Playwright
APIs such as `page.goto`, `page.get_by_role`, `locator.fill`, and Playwright
web-first assertions.

Smartest is also not intended to replace Node.js Playwright Test for
production-like E2E suites that need Playwright traces, reports, browser project
matrices, and parallel workers across deployed environments.

## Quick start

Add Smartest to the test group:

```bash
bundle add smartest --group test
```

Generate the Rails browser-test scaffold:

```bash
bundle exec smartest --init-rails
```

The scaffold creates:

```text
smartest/fixtures/rails_system_fixture.rb
smartest/matchers/playwright_matcher.rb
smartest/example_rails_system_test.rb
```

Smartest uses `smartest/` by default so its files can be run by the Smartest
runner without changing existing Rails `test/` or RSpec `spec/` directories. If
you prefer a Rails-like layout, you can move tests under a structure such as
`smartest/system/` or `test/smartest/system/` and pass that path to
`bundle exec smartest`.

It also adds `playwright-ruby-client` to the Gemfile test group, installs the
Playwright npm package, and downloads browsers.

Prepare the Rails test database:

```bash
bin/rails db:test:prepare
```

Run the generated example:

```bash
bundle exec smartest smartest/example_rails_system_test.rb
```

## Your first Rails browser test

The generated example registers the Rails system fixture and Playwright matcher
from `around_suite`.

```ruby
around_suite do |suite|
  use_fixture RailsSystemTestFixture
  use_matcher PlaywrightMatcher
  suite.run
end
```

A test can request the generated `page:` fixture and use Playwright directly:

```ruby
test("home page is visible") do |page:|
  page.goto("/")

  expect(page.locator("body")).to be_visible
end
```

The `page:` fixture is connected to the Rails test server. A relative URL such
as `"/"` is resolved against the generated Rails server `base_url`.

## Think in Rails state, then browser behavior

The main benefit of Rails system tests is not only that they drive a real
browser. The bigger benefit is that a test can create application state directly
from Ruby.

Smartest keeps that strength and makes the setup visible from the test
signature.

The examples below assume FactoryBot is available and
`FactoryBot::Syntax::Methods` has been included where the fixtures run. If your
app does not use FactoryBot, create records with ActiveRecord directly:

```ruby
fixture :admin_user do
  User.create!(
    name: "Admin",
    email: "admin@example.com",
    role: "admin"
  )
end
```

```ruby
class ApplicationSystemFixture < Smartest::Fixture
  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :suspended_user_page do |page:, suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) do
      suspended_user
    end

    page
  end
end
```

Register the application-specific fixture:

```ruby
around_suite do |suite|
  use_fixture RailsSystemTestFixture
  use_fixture ApplicationSystemFixture
  use_matcher PlaywrightMatcher
  suite.run
end
```

Then request the stateful page fixture from the test:

```ruby
test("suspended user sees account restriction page") do |suspended_user_page:|
  suspended_user_page.goto("/dashboard")

  expect(
    suspended_user_page.get_by_role("heading", name: "Your account is suspended")
  ).to be_visible
end
```

In this example, requesting `suspended_user_page:` means:

1. create a suspended user,
2. stub `ApplicationController#current_user`,
3. open a Playwright page connected to the Rails test server,
4. reset the stub when the test finishes.

The setup is not hidden in a `before` block or helper. It is visible in the test
signature.

## Smartest fixtures are not Rails YAML fixtures

Rails already has "fixtures" for loading database records from YAML files.
Smartest fixtures are different.

A Smartest fixture is a dependency-injected test resource. It can create records,
open browser pages, apply stubs, prepare mailers, configure jobs, or combine
several of those into a named test state.

| Rails concept | Smartest equivalent |
| --- | --- |
| `let(:user) { create(:user) }` | `fixture :user do create(:user) end` |
| `before { login_as(user) }` | `fixture :signed_in_page do |page:, user:| ...; page end` |
| `before { allow(...).to receive(...) }` | `fixture :stubbed_page do |page:| simple_stub(...); page end` |
| `scenario "..." do ... end` | `test("...") do |page:| ... end` |
| hidden setup | explicit keyword fixture dependencies |

A fixture can also depend on other fixtures by keyword argument:

```ruby
fixture :admin_user do
  create(:user, :admin)
end

fixture :admin_page do |page:, admin_user:|
  simple_stub_any_instance_of(ApplicationController, :current_user) do
    admin_user
  end

  page
end
```

## Stateful page fixtures

Rails browser tests are often easier to read when user state, stubs, and the
browser page are combined into a named page fixture.

`simple_stub` and `simple_stub_any_instance_of` are Smartest stub helpers.
Stubs installed inside fixtures are automatically reset during fixture teardown.

```ruby
class ApplicationSystemFixture < Smartest::Fixture
  fixture :admin_user do
    create(:user, :admin)
  end

  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :admin_page do |page:, admin_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) do
      admin_user
    end

    page
  end

  fixture :suspended_user_page do |page:, suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) do
      suspended_user
    end

    page
  end

  fixture :page_with_push_stubbed do |page:|
    simple_stub(PushNotifier, :deliver_later) { :stubbed }

    page
  end
end
```

The examples use `ApplicationController#current_user` stubbing because it shows
how Smartest fixtures can create app-specific browser states. In a real Rails
app, you may prefer your existing authentication helper, Devise/Warden test
helpers, or a cookie/session-based login fixture.

Tests can request the exact state they need:

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

The examples use string paths for simplicity. If you want Rails route helpers
such as `admin_users_path`, expose them from your own fixture or helper module.

This style is especially useful for edge cases that are hard to create by hand
through the UI, such as suspended users, admin-only states, billing failures,
feature flags, push notification failures, or external service failures.

## From Capybara to Playwright

Smartest does not provide Capybara methods. Use Playwright locators instead.

| Capybara | Smartest + Playwright |
| --- | --- |
| `visit root_path` | `page.goto("/")` |
| `fill_in "Email", with: user.email` | `page.get_by_label("Email").fill(user.email)` |
| `click_button "Log in"` | `page.get_by_role("button", name: "Log in").click` |
| `assert_text "Dashboard"` | `expect(page.get_by_text("Dashboard")).to be_visible` |
| `assert_selector "h1", text: "Users"` | `expect(page.locator("h1")).to have_text("Users")` |

Playwright locators wait for the page to become ready before performing many
actions and assertions. This is useful for Rails apps with Turbo, Stimulus,
React, Vue, or other asynchronous UI behavior.

## How the generated Rails fixture works

The generated Rails fixture starts `Rails.application` with
`Smartest::Rails::TestServer`.

```ruby
# frozen_string_literal: true

require "smartest/rails"
require "playwright"

class RailsSystemTestFixture < Smartest::Fixture
  suite_fixture :rails_server do
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

`Smartest::Rails::TestServer` is loaded only when `smartest/rails` is required.
Plain `require "smartest"` does not load Puma.

The generated fixture keeps expensive resources suite-scoped:

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

The Rails app runs in the same Ruby process as the Smartest test runner. This is
important for Rails-native tests that use Ruby-side state, method stubs, and
test helpers.

:::warning

Do not start the app separately with `bin/rails server -e test` for tests that
depend on FactoryBot-created state or method stubs.

If the Rails server runs in another process, stubs installed by the Smartest test
process are not visible to the Rails application process.

:::

## Test server port

By default, the Rails test server asks the OS for an available port.

Set `SMARTEST_RAILS_PORT` when you need a fixed port:

```bash
SMARTEST_RAILS_PORT=4001 bundle exec smartest smartest/example_rails_system_test.rb
```

This is useful when debugging, inspecting browser traffic, or integrating with
tools that expect a stable local port.

## Method stubs

Rails browser tests often need to stub methods that are called inside the Rails
server thread.

Because the generated Rails server runs in the same Ruby process as the test
runner, method stubs installed by Smartest fixtures are visible to the Rails
server thread.

```ruby
fixture :suspended_user_page do |page:, suspended_user:|
  simple_stub_any_instance_of(ApplicationController, :current_user) do
    suspended_user
  end

  page
end
```

The stub is applied during fixture setup and reset from fixture teardown.

:::warning

Smartest method stubs are process-wide. They are visible across Fibers and
Threads in the same Ruby process.

Run Rails browser tests that use method stubs serially inside one Ruby process.
Do not rely on method-stub isolation for multi-threaded parallel test execution.

:::

## Database setup and cleanup

Prepare the test database before running Smartest:

```bash
bin/rails db:test:prepare
bundle exec smartest smartest/example_rails_system_test.rb
```

Browser requests run through the Rails test server. Depending on your database
connection setup, records created inside an uncommitted transaction may not be
visible from the browser request.

A conservative starting point is to use truncation cleanup for browser tests:

```ruby
require "database_cleaner/active_record"

around_suite do |suite|
  DatabaseCleaner[:active_record].clean_with(:truncation)

  around_test do |test|
    DatabaseCleaner[:active_record].strategy = :truncation

    DatabaseCleaner[:active_record].cleaning do
      test.run
    end
  end

  use_fixture RailsSystemTestFixture
  use_matcher PlaywrightMatcher
  suite.run
end
```

If your app setup makes records created by fixtures visible from browser
requests under transaction cleaning, you can switch the per-test strategy to
`:transaction` for faster cleanup:

```ruby
around_test do |test|
  DatabaseCleaner[:active_record].strategy = :transaction

  DatabaseCleaner[:active_record].cleaning do
    test.run
  end
end
```

If records created by Smartest fixtures are not visible from the browser, use
truncation or another application-specific cleanup strategy.

## Parallel execution

Keep Rails browser tests serial by default.

For parallel execution, run each worker in a separate Ruby process with its own
database and Rails test server. Smartest does not provide automatic database
separation or method-stub isolation between parallel workers.

## Troubleshooting

### The Rails app booted in development mode

Make sure `RAILS_ENV` is set before `config/environment` is loaded.

The generated fixture does this before requiring the Rails app:

```ruby
ENV["RAILS_ENV"] ||= "test"
ENV["RACK_ENV"] ||= ENV["RAILS_ENV"]

require_relative "../../config/environment"
```

### Method stubs do not affect the browser request

Check that the Rails app is not running in a separate process.

This will not see stubs installed by the Smartest process:

```bash
bin/rails server -e test
```

Use the generated `RailsSystemTestFixture` so the Rails app runs in the same Ruby
process as the test runner.

### Records created by fixtures are not visible in the browser

Use truncation cleanup instead of transaction cleanup, or adjust your database
connection strategy so the Rails server request can see the records created by
the test.

### The test server port changes every run

Set `SMARTEST_RAILS_PORT`:

```bash
SMARTEST_RAILS_PORT=4001 bundle exec smartest smartest/example_rails_system_test.rb
```

## Summary

Smartest for Rails is best understood as a Rails-native browser test runner:

- Rails test state is created from Ruby.
- Setup is expressed as explicit keyword fixtures.
- Browser behavior is verified with Playwright locators and web-first assertions.
- Rails runs in the same Ruby process as the test runner.
- Stubs and database cleanup should be handled carefully, especially when
  introducing parallel execution.

Use it when you want Rails system-test power with a more explicit fixture model
and Playwright-based browser assertions.
