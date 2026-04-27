# Smartest Development Guide

This document describes how to develop Smartest itself.

For user-facing usage, see `README.md`.

For detailed design rationale, see `SMARTEST_DESIGN.md`.

## Project goals

Smartest is a Ruby test runner focused on:

- top-level test definitions
- class-based fixtures
- explicit keyword-argument fixture dependencies
- optional cleanup for fixtures that need teardown
- suite-scoped fixtures for expensive shared resources
- a small internal architecture that is easy to reason about

The MVP should avoid becoming a full RSpec clone.

## Intended directory structure

```text
smartest/
  lib/
    smartest.rb
    smartest/
      autorun.rb
      version.rb

      dsl.rb
      suite.rb
      test_case.rb
      test_registry.rb

      fixture.rb
      fixture_definition.rb
      fixture_class_registry.rb
      fixture_set.rb
      parameter_extractor.rb

      execution_context.rb

      expectations.rb
      expectation_target.rb
      matchers.rb

      runner.rb
      test_result.rb
      reporter.rb

      errors.rb

  exe/
    smartest

  smartest/
    smartest_test.rb
    fixtures/
      sample_fixture.rb

  documentation/
    docs/

  Gemfile
  smartest.gemspec
  CHANGELOG.md
  Rakefile
  README.md
  DEVELOPMENT.md
  SMARTEST_DESIGN.md
```

## Core modules and classes

### `Smartest`

Top-level namespace.

Responsibilities:

- owns the default suite
- exposes accessors used by the DSL
- loads framework components

Example:

```ruby
module Smartest
  def self.suite
    @suite ||= Suite.new
  end
end
```

### `Smartest::Suite`

A suite groups all mutable test-run state.

Responsibilities:

- test registry
- fixture class registry
- matcher registry
- `around_suite` hook registry

Example shape:

```ruby
class Smartest::Suite
  attr_reader :tests, :fixture_classes

  def initialize
    @tests = TestRegistry.new
    @fixture_classes = FixtureClassRegistry.new
  end
end
```

### `Smartest::DSL`

Provides top-level user methods.

Required methods:

```ruby
test(name, **metadata, &block)
around_suite(&block)
around_test(&block)
```

`use_fixture(klass)` and `use_matcher(matcher_module)` are not top-level DSL
methods. They are available only from hook execution contexts: `around_suite`
and `around_test`.

Possible later methods:

```ruby
before(&block)
after(&block)
```

`Kernel.include Smartest::DSL` should happen only from `smartest/autorun` or the CLI entrypoint.

Do not include DSL globally from `smartest.rb` itself.

### `Smartest::TestCase`

Represents a single test.

Responsibilities:

- stores name
- stores metadata
- stores block
- exposes fixture names required by the test

Example:

```ruby
class Smartest::TestCase
  attr_reader :name, :metadata, :block, :location

  def fixture_names
    ParameterExtractor.required_keyword_names(block)
  end
end
```

`location` should be captured from `caller_locations` when the test is registered.

### `Smartest::ParameterExtractor`

Extracts fixture names from block parameters.

Primary rule:

```ruby
do |user:|
```

means the block requires fixture `:user`.

Implementation direction:

```ruby
class Smartest::ParameterExtractor
  def self.required_keyword_names(block)
    block.parameters.filter_map do |type, name|
      name if type == :keyreq
    end
  end
end
```

MVP should support `:keyreq`.

Optional keyword support can be added later.

### `Smartest::Fixture`

Base class for fixture classes.

User code:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!(name: "Alice")
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

Responsibilities:

- class-level `fixture` DSL
- class-level `suite_fixture` DSL for suite-scoped fixtures
- stores fixture definitions
- supports inheritance
- exposes `cleanup` to fixture blocks
- optionally delegates helper methods to `ExecutionContext`

Fixture definitions should not execute at declaration time.

### `Smartest::FixtureDefinition`

Represents one fixture definition.

Fields:

- name
- block
- dependencies
- location
- scope

Example:

```ruby
class Smartest::FixtureDefinition
  attr_reader :name, :block, :dependencies, :location, :scope

  def initialize(name:, block:, location:, scope: :test)
    @name = name.to_sym
    @block = block
    @scope = scope
    @dependencies = ParameterExtractor.required_keyword_names(block)
    @location = location
  end
end
```

### `Smartest::FixtureClassRegistry`

Stores registered fixture classes.

Responsibilities:

- add fixture class
- return all registered classes
- validate class type if desired

Example:

```ruby
around_suite do |suite|
  use_fixture AppFixture
  suite.run
end
```

should register `AppFixture`.

### `Smartest::FixtureSet`

Fixture resolver for one scope.

A suite-scoped `FixtureSet` is created lazily for shared fixtures. A new
test-scoped `FixtureSet` is created for each test and delegates suite-scoped
fixture requests to the suite set.

Responsibilities:

- instantiate registered fixture classes
- find fixture definitions
- resolve fixture dependencies
- cache fixture values for its scope
- collect cleanup blocks
- run cleanup blocks in reverse order
- detect duplicate fixture names
- detect circular dependencies

Important: regular fixture values must not leak across tests. Suite fixture
values are intentionally shared across the run.

### `Smartest::ExecutionContext`

Object used as `self` when running a test body.

Responsibilities:

- include expectation methods
- include matchers
- expose helper methods
- optionally provide integration helpers later

Tests should run via:

```ruby
context.instance_exec(**kwargs, &test_case.block)
```

### `Smartest::Runner`

Runs tests.

Responsibilities:

- iterate over registered test cases
- run registered `around_suite` hooks around the suite body
- create a lazy suite-scoped `FixtureSet`
- create a fresh `ExecutionContext` per test
- create a fresh `FixtureSet` per test
- resolve test keyword fixtures
- run test body
- run cleanup in `ensure`
- run suite fixture cleanup after all tests
- produce `TestResult`
- notify reporter

`around_suite` hooks receive a run target and must call `suite.run` exactly once.
Registered hooks compose in registration order, so the first hook is the
outermost wrapper. If a hook raises or does not call `suite.run`, the runner
reports a suite failure and exits with status `1`.

Pseudo-code:

```ruby
def run_one(test_case)
  context = ExecutionContext.new
  fixture_set = FixtureSet.new(
    @fixture_classes,
    context: context,
    parent: suite_fixture_set
  )

  kwargs = fixture_set.resolve_keywords(test_case.fixture_names)

  context.instance_exec(**kwargs, &test_case.block)

  TestResult.passed(test_case)
rescue Exception => error
  TestResult.failed(test_case, error)
ensure
  fixture_set&.run_cleanups
end
```

### `Smartest::TestResult`

Represents one test outcome.

Fields:

- test case
- status
- error
- duration

Statuses:

- passed
- failed
- skipped, later

### `Smartest::Reporter`

Console reporter for MVP.

Responsibilities:

- print run start
- print per-test pass/fail
- print failure details
- print summary
- return appropriate exit status through runner

## Fixture resolution

Given:

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

and:

```ruby
test("GET /me") do |logged_in_client:|
end
```

Resolution flow:

```text
resolve :logged_in_client
  resolve :client
    resolve :server
      evaluate server
      cache server
    evaluate client
    cache client
  resolve :user
    evaluate user
    cache user
  evaluate logged_in_client
  cache logged_in_client
run test body
run cleanup stack
```

## Cleanup behavior

Fixture cleanup is optional.

Fixture without teardown:

```ruby
fixture :user do
  User.create!(name: "Alice")
end
```

Fixture with teardown:

```ruby
fixture :server do
  server = TestServer.start
  cleanup { server.stop }

  server.wait_until_ready!
  server
end
```

`cleanup` should register a block on the current fixture set. Regular fixture
cleanups run after the test. `suite_fixture` cleanups run after all tests.

Cleanup blocks must run:

- after the test body
- after the suite for suite-scoped fixtures
- after failed tests
- after fixture setup errors, if cleanup was already registered
- in reverse registration order

Implementation:

```ruby
def add_cleanup(&block)
  @cleanups << block
end

def run_cleanups
  @cleanups.reverse_each(&:call)
end
```

## Circular dependency detection

This should fail:

```ruby
fixture :a do |b:|
  b
end

fixture :b do |a:|
  a
end
```

Expected error:

```text
circular fixture dependency: a -> b -> a
```

Implementation idea:

```ruby
def resolve(name)
  return @cache[name] if @cache.key?(name)

  if @resolving.include?(name)
    raise CircularFixtureDependencyError, ...
  end

  @resolving << name
  # resolve
ensure
  @resolving.pop if @resolving.last == name
end
```

## Duplicate fixture detection

This should fail:

```ruby
class UserFixture < Smartest::Fixture
  fixture :user do
  end
end

class AdminFixture < Smartest::Fixture
  fixture :user do
  end
end
```

Expected error:

```text
duplicate fixture: user
defined in:
  UserFixture
  AdminFixture
```

Detect duplicates when creating a `FixtureSet`, because registered fixture classes are known then.

## Error classes

Recommended errors:

```ruby
module Smartest
  class Error < StandardError; end

  class FixtureNotFoundError < Error; end
  class DuplicateFixtureError < Error; end
  class CircularFixtureDependencyError < Error; end
  class InvalidFixtureParameterError < Error; end
  class AssertionFailed < Error; end
end
```

Avoid rescuing only `StandardError` in the runner if the goal is to report test failures robustly.

However, be careful with `Exception`, because it includes `SystemExit`, `NoMemoryError`, and interrupt-related exceptions.

A practical approach:

- assertion and ordinary errors should become failed tests
- `SystemExit` and `Interrupt` should probably be re-raised

## Expected implementation order

### Phase 1: Basic test runner

- `test`
- registry
- runner
- console reporter
- `expect(...).to eq(...)`

### Phase 2: Keyword fixture injection

- `Smartest::Fixture`
- `fixture :name do ... end`
- `use_fixture` from a hook context
- test block keyword fixture resolution

### Phase 3: Fixture dependencies

- `fixture :client do |server:| ... end`
- dependency extraction with `Proc#parameters`
- recursive fixture resolution
- per-test caching

### Phase 4: Cleanup

- `cleanup { ... }`
- cleanup stack on `FixtureSet`
- cleanup in `ensure`

### Phase 5: Suite-scoped fixtures

- `suite_fixture :name do ... end`
- suite-level fixture cache
- suite cleanup after all tests
- test fixtures may depend on suite fixtures
- suite fixtures may not depend on test fixtures

### Phase 6: Hardening

- circular dependency detection
- duplicate fixture detection
- improved error output
- source locations
- invalid positional argument detection

### Phase 6: CLI

- `exe/smartest`
- load files from ARGV
- default glob `smartest/**/*_test.rb`
- support `path:line` and `path:start-end` filters that run tests whose `test`
  blocks contain or intersect the lines
- add `smartest/` to the load path before loading tests
- generate a `smartest/test_helper.rb` that loads `smartest/fixtures/**/*.rb`
- exit code 0 on success, 1 on failure

### Phase 7: Suite hooks

- `around_suite do |suite| ... end`
- run hooks around the full suite body
- include suite fixture cleanup inside the wrapped body
- report hook failures as suite failures

### Phase 8: Test hooks

- `around_test do |test| ... end`
- snapshot file-local hooks when each test is registered
- run hooks around fixture setup, test body, and fixture cleanup
- expose `use_fixture` and `use_matcher` only inside hook contexts
- make `around_test` registered from `around_suite` suite-wide

## MVP API rules

Supported:

```ruby
test("name") do
end
```

```ruby
test("name") do |user:|
end
```

```ruby
fixture :user do
end
```

```ruby
fixture :client do |server:|
end
```

```ruby
cleanup { ... }
```

```ruby
around_suite do |suite|
  suite.run
end
```

```ruby
around_test do |test|
  test.run
end
```

Not supported in MVP:

```ruby
test("name") do |user|
end
```

```ruby
fixture :client do |server|
end
```

```ruby
fixture :client, with: [:server] do |server|
end
```

```ruby
resource :server do |use|
end
```

The unsupported forms may be added later, but the first implementation should keep the API sharp.

## Handling positional block parameters

If a fixture or test uses positional parameters, fail with a helpful message.

Bad:

```ruby
test("bad") do |user|
end
```

Good error:

```text
Positional fixture parameters are not supported.

Use keyword fixture injection:

  test("bad") do |user:|
    ...
  end
```

Bad:

```ruby
fixture :client do |server|
end
```

Good error:

```text
Positional fixture dependencies are not supported.

Use keyword fixture dependencies:

  fixture :client do |server:|
    ...
  end
```

## Running the test suite

During development:

```bash
bundle exec ruby exe/smartest
```

or:

```bash
rake test
```

Smartest's own test suite is written with the Smartest DSL and runs through
the Smartest CLI.

## Release checklist

Before releasing:

- update `Smartest::VERSION` in `lib/smartest/version.rb`
- update `CHANGELOG.md`
- run the test suite
- verify the CLI
- verify README and documentation examples
- build the gem
- install the built gem locally
- run a sample project against the installed gem
- push the release tag

Example commands:

```bash
rake test
rake build
gem install ./pkg/smartest-0.1.0.gem
git tag 0.1.0
git push origin 0.1.0
```

`rake build` is provided by Bundler's gem tasks. Pushing a tag that matches
`Smartest::VERSION`, such as `0.1.0` or `0.1.0.alpha1`, triggers the Deploy
GitHub Actions workflow. The workflow runs `rake verify`, builds the gem, and
publishes `pkg/smartest-$VERSION.gem` to RubyGems using the `RUBYGEMS_API_KEY`
repository secret.

## Non-goals for the MVP

Do not implement these in the first version:

- nested `describe/context`
- parallel execution
- file-scoped fixtures
- resource fixtures using `use.call`
- RSpec-compatible matcher ecosystem
- snapshot testing
- watch mode
- browser automation integration

These can be added after the core fixture model is stable.
