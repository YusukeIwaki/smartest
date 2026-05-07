# Smartest

[![Gem Version](https://badge.fury.io/rb/smartest.svg)](https://rubygems.org/gems/smartest)

Smartest is a Ruby test runner that brings pytest-style fixtures to Ruby,
with explicit fixture dependencies, automatic teardown, and Playwright-friendly
browser testing.

Tests request fixtures with Ruby keyword arguments. Fixtures define their own
dependencies the same way:

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    on_teardown { server.stop }
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end

around_suite do |suite|
  use_fixture WebFixture
  suite.run
end

test("GET /health") do |client:|
  response = client.get("/health")

  expect(response.status).to eq(200)
end
```

Smartest is designed around three ideas:

1. Tests should be readable at the top level.
2. Fixture dependencies should be explicit.
3. Teardown should be written only when it is needed.

## Why Smartest?

Ruby already has excellent testing tools, but Smartest focuses on a specific
idea: tests should explicitly declare their dependencies.

RSpec `let` is useful when examples need lazy helper methods. Minitest `setup`
is simple for xUnit-style setup. Rails fixtures and FactoryBot are great for
test data. Smartest is aimed at tests where setup resources, dependency graphs,
and teardown should be visible in the test signature and fixture definitions.

```ruby
test("GET /me") do |logged_in_client:|
  response = logged_in_client.get("/me")

  expect(response.status).to eq(200)
end
```

| Tool | Style | Difference from Smartest |
| --- | --- | --- |
| RSpec `let` | Lazy helper method | Tests pull dependencies from inside the example. |
| Minitest `setup` | xUnit setup method | Dependencies often become implicit instance state. |
| Rails fixtures | Database records | Not resource setup or fixture dependency injection. |
| FactoryBot | Test data factories | Not fixture lifecycle management. |
| Smartest | Keyword fixture injection | Tests declare dependencies explicitly. |

## Installation

Smartest requires Ruby 2.7 or newer.

Smartest is published as the `smartest` RubyGem:
[Smartest on RubyGems](https://rubygems.org/gems/smartest).

Add this line to your application's Gemfile:

```ruby
gem "smartest"
```

Then run:

```bash
bundle install
```

Or install it directly:

```bash
gem install smartest
```

## Quick start

Initialize a test scaffold:

```bash
bundle exec smartest --init
```

This creates:

```text
smartest/test_helper.rb
smartest/fixtures/
smartest/matchers/
smartest/matchers/predicate_matcher.rb
smartest/example_test.rb
```

The generated example looks like this:

```ruby
# smartest/example_test.rb
require "test_helper"

test("example") do
  expect(1 + 1).to eq(2)
end
```

Run the suite:

```bash
bundle exec smartest
```

By default, Smartest loads `smartest/**/*_test.rb`, so a separate `test/`
directory can remain available for Minitest.

If `smartest/` does not exist yet and no explicit paths are passed, Smartest
prints scaffold commands instead of attempting a default test run:

```text
No smartest/ directory found.

To create a Smartest test scaffold:
  bundle exec smartest --init

For browser tests:
  bundle exec smartest --init-browser

For Rails browser tests:
  bundle exec smartest --init-rails

See all commands:
  bundle exec smartest --help
```

You can also pass explicit paths:

```bash
bundle exec smartest smartest/suite1/
bundle exec smartest smartest/**/*_test.rb
bundle exec smartest smartest/user_test.rb
```

A directory path is expanded to `**/*_test.rb` under that directory, so
`bundle exec smartest smartest/suite1/` is equivalent to
`bundle exec smartest smartest/suite1/**/*_test.rb`.

To run tests by line number, append `:line` or `:start-end` to the file path.
Smartest runs tests whose `test` blocks contain or intersect the selected lines:

```bash
bundle exec smartest smartest/user_test.rb:12
bundle exec smartest smartest/user_test.rb:3-12
```

Smartest prints the 5 slowest tests after each CLI run by default. Use
`--profile N` to choose a different count:

```bash
bundle exec smartest --profile 10
bundle exec smartest --profile 3 smartest/user_test.rb
```

CLI help and version output are available with:

```bash
bundle exec smartest --help
bundle exec smartest --version
```

The help output lists common commands, including default runs, directory runs,
single-file runs, line-filtered runs, and scaffold generation:

```bash
bundle exec smartest
bundle exec smartest smartest/suite1/
bundle exec smartest smartest/user_test.rb
bundle exec smartest smartest/user_test.rb:12
bundle exec smartest --init
bundle exec smartest --init-browser
bundle exec smartest --init-rails
```

Output resembles:

```text
Running 1 test

✓ example

Top 1 slowest test (0.00001 seconds, 100.0% of total time):
  example
    0.00001 seconds .../smartest/example_test.rb:3

1 test, 1 passed, 0 failed
```

## Playwright quick start

Initialize a browser-test scaffold:

```bash
bundle exec smartest --init-browser
```

The Playwright init command creates the normal Smartest helper, fixtures, and
predicate matcher, then adds:

```text
smartest/fixtures/playwright_fixture.rb
smartest/matchers/playwright_matcher.rb
smartest/example_browser_test.rb
```

It also registers `PlaywrightFixture` and `PlaywrightMatcher`, adds
`playwright-ruby-client` to the Gemfile test group, runs `bundle install`, runs
`npm init --yes` when no `package.json` exists yet, runs
`npm install playwright --save-dev`, and downloads Chromium with
`./node_modules/.bin/playwright install`.

Run the generated browser example with:

```bash
bundle exec smartest smartest/example_browser_test.rb
```

## Rails browser quick start

Initialize a Rails browser-test scaffold:

```bash
bundle exec smartest --init-rails
```

The Rails init command creates the normal Smartest helper, a Rails system
fixture, a Playwright matcher, and `smartest/example_rails_system_test.rb`.
The generated fixture starts `Rails.application` in the test process with Puma,
uses `SMARTEST_RAILS_PORT` when it is set, and otherwise asks the OS for an
available port. The `page` fixture uses a per-test Playwright browser context
with `baseURL` set to the Rails server URL.

The generated helper wraps each test in
`Smartest::SimpleStub.with_process_store(Smartest::SimpleStub::SharedStore.new)`
so method stubs applied in test fixtures can also be seen by the Rails server
thread.

## Defining tests

Use `test` at the top level:

```ruby
test("adds numbers") do
  expect(1 + 2).to eq(3)
end
```

A test can request fixtures using required keyword arguments:

```ruby
test("uses a user") do |user:|
  expect(user.name).to eq("Alice")
end
```

Smartest intentionally favors keyword arguments for fixture injection:

```ruby
test("GET /me") do |logged_in_client:|
  # ...
end
```

This makes fixture usage explicit and avoids relying on positional argument order.

## Skipping and pending tests

Use `skip` at the start of a test when the rest of the body should not run:

```ruby
test("PDF export") do |browser:|
  skip "firefox is not supported" if browser.firefox?

  export_pdf(browser)
end
```

Use `pending` when the test should continue running but is expected to fail. If
the test passes after `pending`, Smartest fails it so the stale pending marker is
removed.

```ruby
test("PDF export") do |browser:|
  pending "Not supported by WebDriver BiDi yet" if browser.bidi?

  export_pdf(browser)
end
```

`skip` and `pending` are available in test bodies and `around_test` hooks, but
not as `test` metadata or fixture APIs. See
[Skipping Tests](documentation/docs/skipping-tests.md).

## Expectations

Smartest uses an expectation style:

```ruby
expect(actual).to eq(expected)
expect(actual).not_to eq(expected)
expect { action }.to raise_error(ErrorClass)
expect { action }.to raise_error(/message/)
expect { action }.to raise_error(ErrorClass, /message/)
expect { action }.to change { value }
expect(actual).to matcher.or(other_matcher)
expect(actual).to matcher.and(other_matcher)
```

Examples:

```ruby
test("string") do
  expect("hello").to eq("hello")
end

test("array") do
  expect([1, 2, 3]).to include(2)
end

test("URL") do
  expect("about:blank").to start_with("about:")
end

test("download") do
  expect("screenshot.png").to end_with(".png")
end

test("type") do
  expect("smartest").to be_a(String)
end

test("URL pattern") do
  expect("https://example.test").to match(%r{\Ahttps://})
end

test("events") do
  expect(%i[request close open]).to contain_exactly(:open, :request, :close)
end
```

Supported matchers include:

```ruby
eq(expected)
include(expected)
start_with(prefix, ...)
end_with(suffix, ...)
be_a(ClassOrModule)
be_an(ClassOrModule)
be_nil
match(regexp)
contain_exactly(item, ...)
match_array(items)
raise_error(ErrorClass)
raise_error(/message/)
raise_error(ErrorClass, /message/)
change { value }
change { value }.from(before).to(after)
change { value }.by(delta)
```

`raise_error` accepts an error class, a message regexp, or both. Use an error
class to check the raised exception class, a regexp to check the raised
exception message, or both to require both conditions. No-argument and exact
string message forms are not supported.

`contain_exactly` and `match_array` compare collections without requiring a
specific order, preserve duplicate counts, and can use matcher objects such as
`match(/foo/)` or `eq(42)` as expected items.

`change` is only supported with `expect { ... }` block expectations and must be
written with a value block.

Matchers can be composed with `.or` and `.and`:

```ruby
expect(result).to include("NetworkError").or include("Failed to fetch")
expect(response.status).to eq(200).or(eq(304))
expect("report.txt").to start_with("report").and end_with(".txt")
```

`.or` passes when any matcher matches and short-circuits the right-hand matcher
when the left-hand matcher passes. `.and` passes only when every matcher matches.
`not_to` does not support composed matchers and raises `ArgumentError` when used
with `.and` or `.or`.

Composed `change` matchers observe one action block execution:

```ruby
expect {
  count += 1
  total += 1
}.to change { count }.by(1).and change { total }.by(1)
```

Custom matcher modules can be registered from `around_suite` or `around_test`
with `use_matcher`. The generated scaffold includes a `PredicateMatcher` custom
matcher for `be_<predicate>` calls. See [Matchers](documentation/docs/matchers.md).

## Fixtures

Fixtures are defined in classes.

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!(
      name: "Alice",
      email: "alice@example.com"
    )
  end
end
```

Register fixture classes from `around_suite` in `smartest/test_helper.rb`:

```ruby
around_suite do |suite|
  use_fixture AppFixture
  suite.run
end
```

Tests request fixtures by keyword:

```ruby
test("user") do |user:|
  expect(user.name).to eq("Alice")
end
```

A fixture is requested by name from a test block keyword argument.

```ruby
test("user") do |user:|
  # Smartest resolves the `user` fixture
end
```

## Fixture dependencies

Fixtures can depend on other fixtures using required keyword arguments.

```ruby
class AppFixture < Smartest::Fixture
  suite_fixture :server do
    TestServer.start
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

The dependency is explicit:

```ruby
fixture :client do |server:|
  Client.new(base_url: server.url)
end
```

When a test requests `client`, Smartest resolves `server` first.

```ruby
test("GET /health") do |client:|
  response = client.get("/health")

  expect(response.status).to eq(200)
end
```

## Fixture scopes

Regular `fixture` definitions are test-scoped. Smartest creates a fresh value
for each test that requests the fixture.

Use `suite_fixture` for expensive resources that should be created once and
released after the full suite finishes:

```ruby
class BrowserFixture < Smartest::Fixture
  suite_fixture :browser do
    browser = Browser.launch
    on_teardown { browser.close }
    browser
  end

  fixture :page do |browser:|
    browser.new_page
  end
end
```

Suite fixtures are lazy: setup runs the first time a test requests the fixture,
and teardown runs once after all tests finish. Test-scoped fixtures can depend on
suite fixtures, but suite fixtures cannot depend on test-scoped fixtures.

## Suite hooks

Use `around_suite` when the full test run must execute inside another block:

```ruby
around_suite do |suite|
  Async do
    suite.run
  end
end
```

The hook receives a run target and must call `suite.run` exactly once. The block
wraps every test, test-scoped fixture setup and teardown, suite fixture setup, and
suite fixture teardown.

Fixture and matcher registrations made before `suite.run` are applied to that
run:

```ruby
around_suite do |suite|
  use_fixture GlobalFixture
  suite.run
end
```

Multiple `around_suite` hooks run in registration order. The first hook is the
outermost wrapper:

```ruby
around_suite do |suite|
  with_outer_resource { suite.run }
end

around_suite do |suite|
  with_inner_resource { suite.run }
end
```

If an `around_suite` hook raises or does not call `suite.run`, Smartest reports a
suite failure and exits with status `1`.

## Test hooks

Use `around_test` when each test needs to run inside another block:

```ruby
around_test do |test|
  SomeAutoCloseResource.new do
    test.run
  end
end
```

The hook receives a run target and must call `test.run` exactly once. It wraps
fixture setup, the test body, and fixture teardown.

`around_test` is file-scoped when it is written directly in a test file. Smartest
copies the current file's `around_test` hooks when each `test` is registered, so
hooks apply to tests defined later in the same file.

Define `around_test` inside `around_suite` when the hook should apply to the
whole run:

```ruby
around_suite do |suite|
  around_test do |test|
    with_some_resource do
      test.run
    end
  end

  suite.run
end
```

`around_test` can also register fixture classes or matcher modules for that test
run:

```ruby
around_test do |test|
  use_fixture LocalFixture
  use_matcher LocalMatcher
  test.run
end
```

Fixture classes registered from `around_test` must define only test-scoped
fixtures. If a class defines `suite_fixture`, register it from `around_suite`
instead so its cache and teardown belong to the suite lifecycle.

`use_fixture` and `use_matcher` are only available inside `around_suite` or
`around_test` blocks. They are not top-level DSL methods.

## Fixtures with teardown

Not every fixture needs teardown. For fixtures that do, use `on_teardown`.

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    on_teardown { server.stop }

    server.wait_until_ready!
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

`on_teardown` blocks run after the fixture's scope finishes. For regular fixtures
that means after the test. For `suite_fixture`, teardown runs after the full
suite.

They are executed in reverse order of registration.

```ruby
fixture :temp_dir do
  dir = Dir.mktmpdir
  on_teardown { FileUtils.rm_rf(dir) }

  dir
end
```

Recommended pattern:

```ruby
fixture :server do
  server = TestServer.start
  on_teardown { server.stop }

  server.wait_until_ready!
  server
end
```

Register teardown immediately after acquiring the resource, before later setup steps that may fail.

## Stubs

Use simple stub helpers when a fixture needs to temporarily replace a Ruby
method and reset it during teardown:

```ruby
class PaymentFixture < Smartest::Fixture
  fixture :payment_gateway_stub do
    simple_stub_any_instance_of(PaymentGateway, :charge) { :approved }
  end
end
```

Register the fixture class from `around_suite` before tests request the fixture:

```ruby
around_suite do |suite|
  use_fixture PaymentFixture
  suite.run
end
```

`use_fixture` is available inside `around_suite` or `around_test` blocks, not as
a top-level method in a test file.

The stub affects existing instances and new instances of the target class in
the current Fiber until it is reset. Other Fibers and Threads continue to see
the original method unless they apply their own stub. Tests can request the
fixture to make the side effect explicit:

```ruby
test("checkout succeeds") do |payment_gateway_stub:|
  expect(Checkout.call).to eq(:paid)
end
```

Use `simple_stub(Time, :now) { fixed_time }` for singleton methods such as class
methods.

Use `with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") { ... }` for
constants in test bodies, `around_test`, or `around_suite`. Constant stubs are
process-global; avoid concurrent tests that stub the same constant.

The method stub helpers call `Smartest::SimpleStub` internally, apply the stub,
register `on_teardown { stub.reset }`, and return the stub object.
`with_stub_const` records the previous constant value, replaces it, yields to
the block, and restores or removes the constant with `ensure`.

`Smartest::SimpleStub#apply` and `#reset` are idempotent in the current Fiber.
`apply!` raises
`Smartest::SimpleStub::AlreadyAppliedError` when the stub is already active in
the current Fiber, and `reset!` raises
`Smartest::SimpleStub::NotAppliedError` when it is not active there. See
[Stubs](documentation/docs/stubs.md).

Rails browser tests can opt into a process-shared stub store with
`Smartest::SimpleStub.with_process_store(Smartest::SimpleStub::SharedStore.new)`,
which lets a same-process Rails server thread see stubs applied by the test.

## Logged-in client example

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    on_teardown { server.stop }

    server.wait_until_ready!
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end

  fixture :user do
    User.create!(
      name: "Alice",
      email: "alice@example.com"
    )
  end

  fixture :logged_in_client do |client:, user:|
    client.login(user)
    client
  end
end
```

```ruby
# smartest/test_helper.rb
around_suite do |suite|
  use_fixture WebFixture
  suite.run
end
```

```ruby
# smartest/web_test.rb
require "test_helper"

test("GET /me") do |logged_in_client:|
  response = logged_in_client.get("/me")

  expect(response.status).to eq(200)
end
```

Dependency graph:

```text
logged_in_client
  ├── client
  │   └── server
  └── user
```

Execution flow:

```text
server setup
client setup
user setup
logged_in_client setup
test body
server teardown
```

## Registering fixture classes

Use `use_fixture` inside `around_suite` from `smartest/test_helper.rb`:

```ruby
around_suite do |suite|
  use_fixture AppFixture
  suite.run
end
```

Multiple fixture classes can be registered:

```ruby
around_suite do |suite|
  use_fixture UserFixture
  use_fixture WebFixture
  use_fixture ApiFixture
  suite.run
end
```

Fixture names must be unique across registered fixture classes.

If two fixture classes define the same fixture name, Smartest raises an error.

## Suite hooks and fixture teardown

Suite hooks are separate from fixture teardown. Use fixture teardown for
resource-specific teardown:

```ruby
fixture :server do
  server = TestServer.start
  on_teardown { server.stop }
  server
end
```

Use `around_suite` for broad suite-level execution context:

```ruby
around_suite do |suite|
  Async { suite.run }
end
```

## Recommended file structure

```text
smartest/
  test_helper.rb
  fixtures/
    app_fixture.rb
    web_fixture.rb
  matchers/
    predicate_matcher.rb
    have_status_matcher.rb
  example_test.rb
```

```ruby
# smartest/test_helper.rb
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each do |matcher_file|
  require matcher_file
end

around_suite do |suite|
  use_fixture WebFixture
  use_matcher PredicateMatcher
  suite.run
end
```

The generated helper loads Ruby files under `smartest/fixtures/` and
`smartest/matchers/` in sorted order. Register suite-wide fixture classes and
matcher modules from `around_suite` with `use_fixture` and `use_matcher`.

Example:

```ruby
# smartest/fixtures/web_fixture.rb
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    on_teardown { server.stop }
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

```ruby
# smartest/example_test.rb
require "test_helper"

test("GET /health") do |client:|
  expect(client.get("/health").status).to eq(200)
end
```

## Design choices

Smartest intentionally does not use this style as the primary API:

```ruby
test("GET /me") do |logged_in_client|
end
```

Instead, Smartest prefers:

```ruby
test("GET /me") do |logged_in_client:|
end
```

Keyword arguments make fixture injection explicit.

Smartest also avoids this fixture dependency style:

```ruby
fixture :client, with: [:server] do |server|
  Client.new(base_url: server.url)
end
```

Instead, it prefers:

```ruby
fixture :client do |server:|
  Client.new(base_url: server.url)
end
```

The dependency declaration and usage are in one place.

## Current scope

Smartest currently focuses on a small runner API:

- top-level `test`
- class-based fixtures
- keyword-argument fixture injection
- fixture dependencies through keyword arguments
- fixture teardown
- suite-scoped fixtures through `suite_fixture`
- fixture-scoped method stubs and block-scoped constant stubs
- suite hooks with `around_suite`
- test hooks with `around_test`
- skipped and pending tests through `skip` and `pending`
- expectation matchers through `expect`
- console reporter
- CLI runner
- circular fixture dependency detection
- duplicate fixture detection

Nested `describe` blocks, watch mode, parallel execution, and file-scoped
fixtures are not part of the current MVP.
