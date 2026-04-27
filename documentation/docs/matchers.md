---
title: Matchers
description: Built-in Smartest matchers and custom matcher registration.
---

# Matchers

Matchers are passed to `expect(actual).to` or `expect(actual).not_to`.

```ruby
expect(actual).to matcher
expect(actual).not_to matcher
```

## Built-in Matchers

### `eq(expected)`

Passes when `actual == expected`:

```ruby
expect(1 + 2).to eq(3)
expect("hello").not_to eq("goodbye")
```

### `include(expected)`

Passes when `actual.include?(expected)` returns true:

```ruby
expect([1, 2, 3]).to include(2)
expect("smartest").to include("test")
```

### `be_nil`

Passes when `actual.nil?` is true:

```ruby
expect(nil).to be_nil
expect("value").not_to be_nil
```

### `raise_error(error_class)`

Passes when the block raises the expected error class:

```ruby
expect { Integer("x") }.to raise_error(ArgumentError)
```

Fatal process-level exceptions such as `SystemExit` and `Interrupt` are re-raised
instead of being treated as assertion failures.

## Generated Predicate Matcher

`smartest --init` creates `smartest/matchers/predicate_matcher.rb` and registers
it from `smartest/test_helper.rb` with `use_matcher PredicateMatcher`.

When enabled, `be_<predicate>` passes if `actual.<predicate>?` returns true:

```ruby
expect([]).to be_empty
expect("value").not_to be_empty
```

Custom predicate methods work the same way:

```ruby
expect(user).to be_active # calls user.active?
```

Arguments are forwarded to the predicate method:

```ruby
expect(2).to be_between(1, 3) # calls 2.between?(1, 3)
```

The predicate matcher is generated as a normal custom matcher module, so projects
that do not want this metaprogramming hook can remove the file and the
`use_matcher PredicateMatcher` line.

## Custom Matchers

Define matcher methods in a module under `smartest/matchers/`.

Matcher methods should return an object that responds to:

- `matches?(actual)`
- `failure_message`
- `negated_failure_message`

```ruby title="smartest/matchers/have_status_matcher.rb"
module HaveStatusMatcher
  class MatcherImpl
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      actual.status == @expected
    end

    def failure_message
      "expected #{@actual.inspect} to have status #{@expected.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to have status #{@expected.inspect}"
    end
  end

  def have_status(expected)
    MatcherImpl.new(expected)
  end
end
```

The generated `smartest/test_helper.rb` loads every Ruby file under
`smartest/matchers/` in sorted order. Register the matcher modules you want to
use with `use_matcher`:

```ruby title="smartest/test_helper.rb" {12}
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each do |matcher_file|
  require matcher_file
end

use_matcher PredicateMatcher
use_matcher HaveStatusMatcher
```

Registered matcher methods are available in every test that requires the helper:

```ruby
Response = Struct.new(:status)

test("response status") do
  expect(Response.new(200)).to have_status(200)
end
```
