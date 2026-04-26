---
title: Errors
description: Smartest errors and common causes.
---

# Errors

Smartest raises framework-specific errors for invalid test and fixture definitions.

## `Smartest::AssertionFailed`

Raised when an expectation fails:

```text
expected 2 to eq 3
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
