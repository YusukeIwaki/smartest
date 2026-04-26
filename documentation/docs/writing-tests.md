---
sidebar_position: 3
title: Writing Tests
description: Define tests with Smartest and make assertions with expectations.
---

# Writing Tests

A Smartest test is a named block:

```ruby
test("adds numbers") do
  expect(1 + 2).to eq(3)
end
```

The name should describe the behavior being checked. If an expectation fails or the block raises an ordinary exception, the test fails.

## Assertions

Smartest uses an expectation style:

```ruby
expect(actual).to eq(expected)
expect(actual).not_to eq(expected)
```

Examples:

```ruby
test("strings") do
  expect("hello").to eq("hello")
end

test("arrays") do
  expect([1, 2, 3]).to include(2)
end

test("nil values") do
  expect(nil).to be_nil
end
```

Block expectations use Ruby blocks:

```ruby
test("raises an error") do
  expect { Integer("not a number") }.to raise_error(ArgumentError)
end
```

## Requesting Fixtures

Tests request fixtures with required keyword arguments:

```ruby
test("uses a user") do |user:|
  expect(user.name).to eq("Alice")
end
```

The keyword name is the fixture name. Smartest resolves `:user` before calling the test block.

Positional parameters are intentionally rejected:

```ruby
test("bad") do |user|
  # Not supported.
end
```

Use the keyword form instead:

```ruby
test("good") do |user:|
  expect(user.name).to eq("Alice")
end
```

## Organizing Test Files

The recommended layout keeps fixtures in their own files and tests in files ending with `_test.rb`:

```text
test/
  fixtures/
    app_fixture.rb
  example_test.rb
```

Example:

```ruby title="test/example_test.rb"
require "smartest/autorun"
require_relative "fixtures/app_fixture"

use_fixture AppFixture

test("user name") do |user:|
  expect(user.name).to eq("Alice")
end
```

Smartest does not currently provide `describe` or `context` blocks. Prefer clear test names and small files while the MVP API stays focused.
