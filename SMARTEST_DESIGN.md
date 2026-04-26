# Smartest Design

This document records the design of Smartest.

Smartest is a Ruby test runner inspired by pytest, Vitest, and Playwright Test, but with an API that should feel natural in Ruby.

## Design summary

Smartest provides:

```ruby
test("factorial") do
  expect(1 * 2 * 3).to eq(6)
end
```

Fixture usage:

```ruby
test("GET /me") do |logged_in_client:|
  response = logged_in_client.get("/me")

  expect(response.status).to eq(200)
end
```

Fixture definitions:

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
    User.create!(email: "alice@example.com")
  end

  fixture :logged_in_client do |client:, user:|
    client.login(user)
    client
  end
end

use_fixture WebFixture
```

The core decision is:

> Fixture dependencies and test fixture usage are expressed as required keyword arguments.

## Why keyword arguments?

Several forms were considered.

### Positional test fixture injection

```ruby
test("GET /me") do |logged_in_client|
end
```

This is concise and close to pytest.

However, in Ruby it reads like an ordinary block argument. It is not obvious that the value is injected by name.

It also creates ambiguity:

```ruby
test("example") do |user, article|
end
```

Are `user` and `article` matched by position or by name?

Smartest avoids this ambiguity.

### Keyword test fixture injection

```ruby
test("GET /me") do |logged_in_client:|
end
```

This reads as named input to the test.

Ruby exposes the name clearly through `Proc#parameters`:

```ruby
proc { |logged_in_client:| }.parameters
# => [[:keyreq, :logged_in_client]]
```

This gives Smartest a stable way to discover requested fixtures.

### `with:` fixture dependencies

Considered:

```ruby
fixture :client, with: [:server] do |server|
  Client.new(base_url: server.url)
end
```

This makes dependency declaration explicit, but it duplicates information.

The dependency appears in two places:

```ruby
with: [:server]
do |server|
```

This can drift:

```ruby
fixture :client, with: [:user, :server] do |server, user|
end
```

Keyword arguments avoid this:

```ruby
fixture :client do |server:, user:|
end
```

The names are the API. The order does not matter.

### Implicit method-call fixture dependencies

Considered:

```ruby
fixture :client do
  Client.new(base_url: server.url)
end
```

This is very Ruby-like, but dependency discovery requires executing code.

It makes static dependency analysis difficult.

It also makes circular dependency detection later and less clear.

Smartest prefers:

```ruby
fixture :client do |server:|
  Client.new(base_url: server.url)
end
```

Dependencies are explicit and discoverable before fixture execution.

## Why not `resource` for setup/teardown?

Playwright Test-style fixtures often use a `use` callback:

```ruby
fixture :server do |use|
  server = TestServer.start

  use.call(server)
ensure
  server&.stop
end
```

This is powerful because the fixture surrounds the test body.

However, it complicates the execution model.

To support this fully, Smartest would need to build an around-chain:

```text
server setup
  temp_dir setup
    test body
  temp_dir teardown
server teardown
```

This is especially complex when fixtures depend on other fixtures.

Smartest instead chooses `cleanup` for the MVP:

```ruby
fixture :server do
  server = TestServer.start
  cleanup { server.stop }

  server.wait_until_ready!
  server
end
```

This has several advantages:

- fixtures always return values
- teardown is optional
- teardown is local to the fixture that owns the resource
- implementation is simple
- fixture dependencies remain ordinary recursive resolution
- cleanup runs in `ensure`

Not every fixture needs teardown, so teardown should not shape the entire fixture API.

## Fixture model

A fixture is a named value provider.

```ruby
fixture :user do
  User.create!(name: "Alice")
end
```

A fixture may depend on other fixtures.

```ruby
fixture :article do |user:|
  Article.create!(author: user)
end
```

A fixture may register cleanup.

```ruby
fixture :temp_dir do
  dir = Dir.mktmpdir
  cleanup { FileUtils.rm_rf(dir) }
  dir
end
```

A fixture value is cached per test.

Within one test, resolving the same fixture multiple times returns the same value.

Across tests, fixtures are re-created.

## Test model

A test is a named block.

```ruby
test("name") do
end
```

A test may request fixtures through required keyword arguments.

```ruby
test("name") do |user:, article:|
end
```

Smartest resolves these names and calls:

```ruby
context.instance_exec(**kwargs, &test_case.block)
```

The test body runs with `self` set to an `ExecutionContext`.

## Execution context

The execution context is the object used as `self` for test bodies.

Responsibilities:

- provide `expect`
- provide matchers such as `eq`
- provide test helper methods
- avoid polluting global objects

Tests are run as:

```ruby
context.instance_exec(**fixtures, &block)
```

This keeps the top-level DSL small.

Only `test`, `fixture`, and `use_fixture` need to be globally available when using `smartest/autorun`.

## Core architecture

```text
Smartest
  └── Suite
        ├── TestRegistry
        └── FixtureClassRegistry

Runner
  ├── loads TestCase objects
  ├── creates ExecutionContext
  ├── creates FixtureSet
  ├── resolves keyword fixtures
  ├── executes test body
  ├── runs cleanup
  └── reports TestResult
```

## Runtime flow

Given:

```ruby
test("GET /me") do |logged_in_client:|
end
```

and fixtures:

```ruby
fixture :logged_in_client do |client:, user:|
  client.login(user)
  client
end

fixture :client do |server:|
  Client.new(base_url: server.url)
end

fixture :server do
  server = TestServer.start
  cleanup { server.stop }
  server
end

fixture :user do
  User.create!(email: "alice@example.com")
end
```

Resolution:

```text
test requires logged_in_client

resolve logged_in_client
  requires client
    resolve client
      requires server
        resolve server
          evaluate server block
          register cleanup
          cache server
      evaluate client block with server:
      cache client
  requires user
    resolve user
      evaluate user block
      cache user
  evaluate logged_in_client block with client:, user:
  cache logged_in_client

execute test body with logged_in_client:

run cleanup stack in reverse order
```

## Fixture caching

`FixtureSet` owns a per-test cache.

```ruby
@cache = {
  server: server_object,
  client: client_object,
  user: user_object
}
```

The cache is created fresh for each test.

This prevents test pollution.

## Cleanup stack

`FixtureSet` owns a per-test cleanup stack.

```ruby
@cleanups = []
```

Fixture blocks can call:

```ruby
cleanup { resource.close }
```

This delegates to:

```ruby
fixture_set.add_cleanup(&block)
```

After the test, cleanup runs in reverse order:

```ruby
@cleanups.reverse_each(&:call)
```

Reverse order matters because later resources may depend on earlier ones.

Example:

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

Cleanup should run:

```text
browser.close
server.stop
```

## Dependency extraction

Smartest uses `Proc#parameters`.

Required keyword arguments:

```ruby
proc { |server:| }.parameters
# => [[:keyreq, :server]]
```

Fixture dependencies are extracted from fixture blocks:

```ruby
fixture :client do |server:|
end
```

Test fixture usage is extracted from test blocks:

```ruby
test("name") do |client:|
end
```

MVP rule:

- `:keyreq` means fixture dependency or fixture usage
- positional parameters are invalid
- optional keyword parameters are not required for MVP

Future rule:

- `:key` may mean optional fixture injection
- if fixture exists, inject it
- otherwise let Ruby default value apply

## Invalid positional parameters

Smartest should reject this in tests:

```ruby
test("bad") do |user|
end
```

and this in fixtures:

```ruby
fixture :client do |server|
end
```

Reason:

- positional injection is ambiguous
- keyword injection is explicit
- the API should remain sharp

Suggested error for test:

```text
Positional fixture parameters are not supported.

Use keyword fixture injection:

  test("bad") do |user:|
    ...
  end
```

Suggested error for fixture:

```text
Positional fixture dependencies are not supported.

Use keyword fixture dependencies:

  fixture :client do |server:|
    ...
  end
```

## Duplicate fixtures

If multiple registered fixture classes define the same fixture name, Smartest should fail.

Example:

```ruby
class UserFixture < Smartest::Fixture
  fixture :user do
  end
end

class AdminFixture < Smartest::Fixture
  fixture :user do
  end
end

use_fixture UserFixture
use_fixture AdminFixture
```

Error:

```text
duplicate fixture: user
defined in:
  UserFixture
  AdminFixture
```

Detection should happen when a `FixtureSet` is created.

## Circular dependencies

This should fail:

```ruby
fixture :a do |b:|
  b
end

fixture :b do |a:|
  a
end
```

Error:

```text
circular fixture dependency: a -> b -> a
```

Implementation uses a resolving stack:

```ruby
@resolving = []

def resolve(name)
  return @cache[name] if @cache.key?(name)

  if @resolving.include?(name)
    raise CircularFixtureDependencyError
  end

  @resolving << name
  # resolve
ensure
  @resolving.pop if @resolving.last == name
end
```

## Fixture class inheritance

Fixture classes should support inheritance.

Example:

```ruby
class RailsFixture < Smartest::Fixture
  fixture :app do
    Rails.application
  end
end

class UserFixture < RailsFixture
  fixture :user do
    User.create!(name: "Alice")
  end
end
```

`UserFixture.fixture_definitions` should include both `:app` and `:user`.

Implementation approach:

```ruby
def self.fixture_definitions
  inherited =
    if superclass.respond_to?(:fixture_definitions)
      superclass.fixture_definitions
    else
      {}
    end

  inherited.merge(@fixture_definitions || {})
end
```

Child definitions override parent definitions with the same name within the inheritance chain.

Duplicate detection applies across registered fixture classes, not parent-child internal merging.

## Fixture instances

Each test gets fresh fixture class instances.

```text
test A
  WebFixture.new
  cache: {}

test B
  WebFixture.new
  cache: {}
```

This prevents instance variable leakage between tests.

Fixture block execution happens on the fixture instance:

```ruby
fixture_instance.instance_exec(**dependencies, &definition.block)
```

This allows fixture helper methods and `cleanup` to be private instance methods.

## Helper methods in fixtures

Fixture classes may have helper methods:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    create_user
  end

  private

  def create_user
    User.create!(name: "Alice")
  end
end
```

Fixture blocks can call private methods because they execute with `instance_exec`.

Fixture classes may optionally delegate missing methods to the execution context.

This is useful for integration helpers.

Example:

```ruby
fixture :logged_in_user do |user:|
  login_as(user)
  user
end
```

If `login_as` is defined on `ExecutionContext`, `Fixture#method_missing` may delegate to it.

This should be used carefully. Fixture dependencies themselves should still be keyword arguments, not method-missing calls.

## Expectations

MVP expectation API:

```ruby
expect(actual).to eq(expected)
expect(actual).not_to eq(expected)
```

Internal model:

```text
expect(actual)
  => ExpectationTarget

eq(expected)
  => EqMatcher

ExpectationTarget#to(matcher)
  => matcher.match!(actual)
```

Example:

```ruby
class Smartest::ExpectationTarget
  def initialize(actual)
    @actual = actual
  end

  def to(matcher)
    matcher.match!(@actual)
  end

  def not_to(matcher)
    matcher.not_match!(@actual)
  end
end
```

Assertion failures should raise `Smartest::AssertionFailed`.

## Reporter

The initial reporter should be simple.

Example output:

```text
Running 3 tests

✓ factorial
✓ GET /health
✗ GET /me

Failures:

1) GET /me
   expected 500 to eq 200

3 tests, 2 passed, 1 failed
```

Future reporters may include:

- documentation reporter
- dot reporter
- JSON reporter
- GitHub Actions reporter

## CLI

The CLI should support:

```bash
bundle exec smartest
```

If no paths are given:

```bash
bundle exec smartest
```

should default to:

```text
smartest/**/*_test.rb
```

CLI flow:

```ruby
require "smartest"

Kernel.include Smartest::DSL
$LOAD_PATH.unshift File.expand_path("smartest", Dir.pwd)

files = ARGV.empty? ? Dir["smartest/**/*_test.rb"] : ARGV
files.each { |file| require File.expand_path(file) }

exit Smartest::Runner.new.run
```

`smartest/autorun` should use `at_exit`.

```ruby
require "smartest"

Kernel.include Smartest::DSL

at_exit do
  exit Smartest::Runner.new.run
end
```

Care must be taken not to run twice if both CLI and autorun are used.

## Exit status

- all tests passed: `0`
- any test failed: `1`
- configuration/load error: `1`
- interrupted: re-raise or exit non-zero

## Metadata

`test` should accept metadata:

```ruby
test("name", skip: true) do
end

test("name", tags: [:db]) do
end
```

MVP can store metadata without implementing all behavior.

Useful metadata later:

- `skip: true`
- `only: true`
- `tags: [:db]`
- `timeout: 5`

## Hooks

Hooks are separate from fixtures.

Potential API:

```ruby
before do
  DatabaseCleaner.start
end

after do
  DatabaseCleaner.clean
end
```

Hooks should run around each test.

Order:

```text
before hooks
fixture setup
test body
fixture cleanup
after hooks
```

Alternative order:

```text
fixture setup
before hooks
test body
after hooks
fixture cleanup
```

This needs a final decision later.

For MVP, hooks can be omitted.

Fixture cleanup already handles resource-specific teardown.

## Scoping

MVP supports only test-scoped fixtures.

Every test gets fresh fixture instances and fixture values.

Future scopes:

```ruby
fixture :server, scope: :suite do
end
```

Possible scopes:

- `:test`
- `:file`
- `:suite`

Do not implement scopes in MVP.

Suite-scoped fixtures introduce test pollution, parallel execution concerns, and lifecycle complexity.

## Parallel execution

MVP should not support parallel execution.

Current design can later support parallel execution if:

- each worker has an isolated suite or immutable suite definition
- each test has its own fixture set
- reporters are made thread/process safe
- global DSL registration is controlled

## Why class-based fixtures?

Top-level fixture definitions are simple:

```ruby
fixture(:user) do
end
```

But class-based fixtures are more Ruby-like for larger suites.

Benefits:

- grouping
- inheritance
- private helper methods
- reusable fixture modules
- clearer organization
- fewer global definitions
- natural place for cleanup helper

Example:

```ruby
class WebFixture < Smartest::Fixture
  fixture :server do
  end

  private

  def build_url(path)
  end
end
```

## Fixture definition styles considered

### Plain public methods

```ruby
class AppFixture < Smartest::Fixture
  def user
    User.create!
  end
end
```

Pros:

- very Ruby-like
- excellent editor support
- easy helper composition

Cons:

- unclear which public methods are fixtures
- harder to list fixtures
- harder to detect duplicates
- harder to attach metadata
- caching is less obvious

### `fixture :name do`

Chosen:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!
  end
end
```

Pros:

- explicit fixture declaration
- easy metadata later
- easy dependency extraction
- easy duplicate detection
- easy source locations
- easy cleanup integration

### `fixture def user`

Considered:

```ruby
fixture def user
  User.create!
end
```

Pros:

- clever Ruby syntax
- method-like

Cons:

- surprising
- formatter/tooling concerns
- less obvious for users

Not chosen for MVP.

## Resource fixtures considered

Considered:

```ruby
resource :server do |use|
  server = TestServer.start
  use.call(server)
ensure
  server&.stop
end
```

Not chosen for MVP.

Reason:

- requires around-chain execution
- complicates dependency handling
- not needed if `cleanup` exists
- makes fixture API more complex

Could be added later as advanced API.

## Final MVP API

```ruby
# smartest/test_helper.rb
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end
```

```ruby
# smartest/fixtures/app_fixture.rb
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!(name: "Alice")
  end

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

use_fixture AppFixture

test("GET /health") do |client:|
  expect(client.get("/health").status).to eq(200)
end
```

## Future ideas

Possible future features:

- `skip`
- `only`
- tags
- custom reporters
- JSON output
- richer matchers
- block expectations
- `raise_error`
- hooks
- suite-scoped fixtures
- file-scoped fixtures
- parallel execution
- watch mode
- Rails integration
- Capybara integration
- Playwright/Puppeteer integration
- snapshot assertions
- fixture graph visualization

## Design principles

1. Prefer explicit fixture names.
2. Prefer Ruby keyword arguments over positional fixture injection.
3. Keep fixture teardown optional.
4. Keep fixture values test-scoped by default.
5. Avoid global mutable state except the active suite used by the DSL.
6. Keep MVP small.
7. Make errors helpful.
8. Do not copy RSpec's object model unless needed.
9. Do not copy pytest syntax blindly; adapt it to Ruby.
10. Make the common case beautiful.
