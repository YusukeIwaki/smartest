# Smartest

Smartest is a small Ruby test runner with a keyword-fixture-first design.

It lets you write tests like this:

```ruby
test("factorial") do
  expect(1 * 2 * 3).to eq(6)
end
```

and fixture-driven tests like this:

```ruby
test("GET /me") do |logged_in_client:|
  response = logged_in_client.get("/me")

  expect(response.status).to eq(200)
end
```

Smartest is designed around three ideas:

1. Tests should be readable at the top level.
2. Fixture dependencies should be explicit.
3. Teardown should be written only when it is needed.

## Installation

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

You can also pass explicit paths:

```bash
bundle exec smartest smartest/**/*_test.rb
```

To run tests by line number, append `:line` or `:start-end` to the file path.
Smartest runs tests whose `test` blocks contain or intersect the selected lines:

```bash
bundle exec smartest smartest/user_test.rb:12
bundle exec smartest smartest/user_test.rb:3-12
```

CLI help and version output are available with:

```bash
bundle exec smartest --help
bundle exec smartest --version
```

Expected output:

```text
Running 1 test

✓ example

1 test, 1 passed, 0 failed
```

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

## Expectations

Smartest uses an expectation style:

```ruby
expect(actual).to eq(expected)
expect(actual).not_to eq(expected)
```

Examples:

```ruby
test("string") do
  expect("hello").to eq("hello")
end

test("array") do
  expect([1, 2, 3]).to include(2)
end
```

Supported matchers include:

```ruby
eq(expected)
include(expected)
be_nil
raise_error(ErrorClass)
```

Custom matcher modules can be registered with `use_matcher`. The generated
scaffold includes a `PredicateMatcher` custom matcher for `be_<predicate>` calls.
See [Matchers](documentation/docs/matchers.md).

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

Register fixture classes from `smartest/test_helper.rb`:

```ruby
use_fixture AppFixture
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
    cleanup { browser.close }
    browser
  end

  fixture :page do |browser:|
    browser.new_page
  end
end
```

Suite fixtures are lazy: setup runs the first time a test requests the fixture,
and cleanup runs once after all tests finish. Test-scoped fixtures can depend on
suite fixtures, but suite fixtures cannot depend on test-scoped fixtures.

## Fixtures with teardown

Not every fixture needs teardown. For fixtures that do, use `cleanup`.

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    cleanup { server.stop }

    server.wait_until_ready!
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

`cleanup` blocks run after the fixture's scope finishes. For regular fixtures
that means after the test. For `suite_fixture`, cleanup runs after the full
suite.

They are executed in reverse order of registration.

```ruby
fixture :temp_dir do
  dir = Dir.mktmpdir
  cleanup { FileUtils.rm_rf(dir) }

  dir
end
```

Recommended pattern:

```ruby
fixture :server do
  server = TestServer.start
  cleanup { server.stop }

  server.wait_until_ready!
  server
end
```

Register cleanup immediately after acquiring the resource, before later setup steps that may fail.

## Logged-in client example

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    cleanup { server.stop }

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
use_fixture WebFixture
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
server cleanup
```

## Registering fixture classes

Use `use_fixture` from `smartest/test_helper.rb`:

```ruby
use_fixture AppFixture
```

Multiple fixture classes can be registered:

```ruby
use_fixture UserFixture
use_fixture WebFixture
use_fixture ApiFixture
```

Fixture names must be unique across registered fixture classes.

If two fixture classes define the same fixture name, Smartest raises an error.

## Hooks

Smartest may support simple hooks:

```ruby
before do
  DatabaseCleaner.start
end

after do
  DatabaseCleaner.clean
end
```

Hooks are separate from fixture cleanup.

Use fixture cleanup for resource-specific teardown:

```ruby
fixture :server do
  server = TestServer.start
  cleanup { server.stop }
  server
end
```

Use hooks for broad test-level behavior:

```ruby
before do
  reset_global_state
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

use_fixture WebFixture
use_matcher PredicateMatcher
```

The generated helper loads Ruby files under `smartest/fixtures/` and
`smartest/matchers/` in sorted order. Register fixture classes and matcher
modules from the helper with `use_fixture` and `use_matcher`.

Example:

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

## Status

Smartest is currently a design-stage test runner.

The intended MVP includes:

- top-level `test`
- class-based fixtures
- keyword-argument fixture injection
- fixture dependencies through keyword arguments
- fixture cleanup
- `expect(...).to eq(...)`
- console reporter
- CLI runner
- circular fixture dependency detection
- duplicate fixture detection
