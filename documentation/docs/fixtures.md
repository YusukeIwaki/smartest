---
sidebar_position: 5
title: Fixtures
description: Define class-based Smartest fixtures with keyword dependencies and cleanup.
---

# Fixtures

Fixtures are named values that Smartest creates for each test.

They are defined in classes that inherit from `Smartest::Fixture`:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.new(name: "Alice")
  end
end
```

Register fixture classes from `around_suite` in `smartest/test_helper.rb` with
`use_fixture`:

```ruby title="smartest/test_helper.rb" {7-10}
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

around_suite do |suite|
  use_fixture AppFixture
  suite.run
end
```

Tests can then request fixtures by keyword:

```ruby {1}
test("user") do |user:|
  expect(user.name).to eq("Alice")
end
```

## Loading Fixture Files

The generated `smartest/test_helper.rb` loads every Ruby file under
`smartest/fixtures/` in sorted order:

```ruby title="smartest/test_helper.rb"
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

around_suite do |suite|
  use_fixture AppFixture
  suite.run
end
```

Test files can require only the helper, then request the registered fixtures:

```ruby
require "test_helper"

test("user") do |user:|
  expect(user.name).to eq("Alice")
end
```

## Keyword Dependencies

Fixtures can depend on other fixtures with required keyword arguments:

```ruby
class WebFixture < Smartest::Fixture
  suite_fixture :server do
    TestServer.start
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

Register the fixture class from `smartest/test_helper.rb`:

```ruby title="smartest/test_helper.rb"
around_suite do |suite|
  use_fixture WebFixture
  suite.run
end
```

When a test requests `client`, Smartest resolves `server` first:

```ruby
test("GET /health") do |client:|
  response = client.get("/health")

  expect(response.status).to eq(200)
end
```

## Per-Test Caching

Fixture values are cached within one test:

```ruby
fixture :token do
  Object.new
end

fixture :first do |token:|
  token
end

fixture :second do |token:|
  token
end
```

If a test requests both `first` and `second`, both fixtures receive the same `token` object for that test.

The next test gets a fresh cache and fresh fixture instances for regular
test-scoped fixtures.

## Fixture Scope

Smartest supports test-scoped fixtures and suite-scoped fixtures.

Regular `fixture` definitions are test-scoped. Every test gets:

- a new `FixtureSet`
- new fixture class instances
- a fresh fixture value cache
- a fresh cleanup stack

That means a regular fixture runs once for each test that needs it:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!(name: "Alice")
  end
end
```

Use `suite_fixture` for expensive resources that should be shared for the whole
suite, such as a database connection or browser process:

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

Suite fixtures are lazy. Setup runs the first time a test requests the fixture,
and cleanup runs once after all tests finish.

Test-scoped fixtures can depend on suite fixtures:

```ruby
fixture :page do |browser:|
  browser.new_page
end
```

Suite fixtures cannot depend on test-scoped fixtures, because there is no single
test-scoped value that can safely be shared across the full suite.

File-scoped or module-scoped fixtures are not implemented yet.

## Cleanup

Use `cleanup` when a fixture owns a resource that must be released:

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    cleanup { server.stop }

    server.wait_until_ready!
    server
  end
end
```

Register cleanup immediately after acquiring the resource. Cleanup runs even if a later setup step or the test body fails.

For regular fixtures, cleanup runs after the test finishes. For `suite_fixture`,
cleanup runs once after the full suite finishes.

Cleanups run in reverse registration order. If `browser` depends on `server`, the browser cleanup runs before the server cleanup:

```ruby
fixture :server do
  server = TestServer.start
  cleanup { server.stop }
  server
end

fixture :browser do |server:|
  browser = Browser.launch(server.url)
  cleanup { browser.close }
  browser
end
```

## Duplicate Fixture Names

Fixture names must be unique across registered fixture classes:

```ruby title="smartest/test_helper.rb"
around_suite do |suite|
  use_fixture UserFixture
  use_fixture AdminFixture
  suite.run
end
```

If both classes define `fixture :user`, Smartest fails with a duplicate fixture error.

Within one inheritance chain, a child fixture class may override a fixture from its parent.

## Circular Dependencies

Circular dependencies are detected:

```ruby
fixture :a do |b:|
  b
end

fixture :b do |a:|
  a
end
```

Smartest reports the dependency path:

```text
circular fixture dependency: a -> b -> a
```

## Fixture Helper Methods

Fixture blocks execute on an instance of the fixture class, so private helper methods are available:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    build_user("Alice")
  end

  private

  def build_user(name)
    User.new(name: name)
  end
end
```

This keeps setup logic close to the fixtures that use it.
