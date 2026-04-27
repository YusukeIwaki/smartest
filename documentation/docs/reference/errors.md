---
title: Errors
description: Smartest errors and common causes.
---

# Errors

Smartest raises framework-specific errors for invalid test and fixture
definitions, assertion failures, and test status control flow.

## `Smartest::AssertionFailed`

Raised when an expectation fails:

```text
expected 2 to eq 3
```

## `Smartest::Skipped`

Used internally when `skip` stops a test body or `around_test` hook. Smartest
reports the test as skipped instead of failed:

```text
- PDF export (skipped: firefox is not supported)
```

## `Smartest::PendingPassedError`

Raised when a test calls `pending` but then passes:

```text
expected pending test to fail, but it passed: Not supported by WebDriver BiDi yet
```

## `Smartest::FixtureNotFoundError`

Raised when a test or fixture requests a fixture name that is not registered:

```ruby
test("needs user") do |user:|
  expect(user.name).to eq("Alice")
end
```

If no registered fixture class defines `fixture :user`, the test fails.

## `Smartest::DuplicateFixtureError`

Raised when multiple registered fixture classes define the same fixture name.

Fix it by renaming one fixture, registering only one fixture class, or using fixture class inheritance when intentional overriding is needed.

## `Smartest::CircularFixtureDependencyError`

Raised when fixture dependencies form a cycle:

```text
circular fixture dependency: a -> b -> a
```

Break the cycle by extracting shared setup into a lower-level fixture.

## `Smartest::InvalidFixtureScopeError`

Raised when a fixture is defined with an unsupported internal scope.

Use `fixture` for test-scoped fixtures and `suite_fixture` for suite-scoped
fixtures:

```ruby
class AppFixture < Smartest::Fixture
  suite_fixture :database do
    Database.connect
  end
end
```

## `Smartest::InvalidFixtureScopeDependencyError`

Raised when a suite-scoped fixture depends on a test-scoped fixture:

```ruby
class AppFixture < Smartest::Fixture
  fixture :user do
    User.create!(name: "Alice")
  end

  suite_fixture :browser do |user:|
    Browser.launch(user: user)
  end
end
```

Test-scoped fixtures may depend on suite-scoped fixtures. Suite-scoped fixtures
may depend only on other suite-scoped fixtures.

## `Smartest::InvalidFixtureParameterError`

Raised when a test or fixture block uses positional parameters:

```ruby
test("bad") do |user|
end
```

Use required keyword arguments:

```ruby
test("good") do |user:|
end
```

## `Smartest::AroundSuiteRunError`

Raised when an `around_suite` hook does not call `suite.run`, or calls it more
than once:

```ruby
around_suite do |_suite|
  # Missing suite.run.
end
```

Each `around_suite` hook must call `suite.run` exactly once.

## `Smartest::AroundTestFixtureScopeError`

Raised when `around_test` registers a fixture class that defines
`suite_fixture`:

```ruby
around_test do |test|
  use_fixture LocalFixtureWithSuiteFixture
  test.run
end
```

Register fixture classes with suite-scoped fixtures from `around_suite` instead.

## `Smartest::AroundTestRunError`

Raised when an `around_test` hook does not call `test.run`, calls it more than
once, or tries to call `use_fixture` or `use_matcher` after `test.run`:

```ruby
around_test do |_test|
  # Missing test.run.
end
```

Each `around_test` hook must call `test.run` exactly once.
