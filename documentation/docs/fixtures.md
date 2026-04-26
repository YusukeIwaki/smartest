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

Register a fixture class with `use_fixture`:

```ruby
use_fixture AppFixture

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
```

Test files can require only the helper, then register the fixture classes they
need:

```ruby
require "test_helper"

use_fixture AppFixture
```

## Keyword Dependencies

Fixtures can depend on other fixtures with required keyword arguments:

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
    TestServer.start
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

When a test requests `client`, Smartest resolves `server` first:

```ruby
use_fixture WebFixture

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

The next test gets a fresh cache and fresh fixture instances.

## Fixture Scope

Smartest currently supports only test-scoped fixtures.

Every test gets:

- a new `FixtureSet`
- new fixture class instances
- a fresh fixture value cache
- a fresh cleanup stack

That means this fixture runs once for each test that needs it:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!(name: "Alice")
  end
end
```

Suite-scoped, file-scoped, or module-scoped fixtures are not implemented yet:

```ruby
fixture :server, scope: :suite do
  # Not supported in the current MVP.
end
```

The current `fixture` DSL accepts only a fixture name and a block:

```ruby
fixture :server do
  TestServer.start
end
```

If a future version adds scopes, the documentation should describe lifecycle, caching, cleanup timing, and interaction with parallel execution before the API is released.

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

```ruby
use_fixture UserFixture
use_fixture AdminFixture
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
