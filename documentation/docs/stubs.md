---
title: Stubs
description: Stub Ruby methods from Smartest fixtures, with optional autouse-style hook setup and automatic teardown.
---

# Stubs

Smartest provides small stub helpers for replacing Ruby methods during a test.
Put method stubs in fixtures by default. The fixture keyword makes the test
state visible in the test signature, and Smartest resets the stub
automatically when the fixture is torn down.

## Fixture-Scoped Method Stubs

Define the stub in a fixture and request that fixture from each test that needs
the replacement:

```ruby
class EdgeCaseFixture < Smartest::Fixture
  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :suspended_user_logged_in do |suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) { suspended_user }
    suspended_user
  end
end
```

Register the fixture class from `around_suite` before tests request the fixture:

```ruby
around_suite do |suite|
  use_fixture EdgeCaseFixture
  suite.run
end
```

Then request the fixture from the test:

```ruby
test("shows the suspended account state") do |suspended_user_logged_in:|
  expect(AccountStatus.call).to eq(:suspended)
end
```

The fixture name makes it clear that this test depends on an authenticated
suspended user.

`use_fixture` is available inside `around_suite` or `around_test` blocks, not as
a top-level method in a test file.

The stub is automatically reset when the fixture is torn down. Because the stub
fixture depends on `suspended_user:`, the user record and authenticated state
stay tied together in one fixture dependency graph.

If you are familiar with RSpec, the fixture replaces setup that might otherwise
live in a `before` hook:

```ruby
let(:suspended_user) { create(:user, :suspended) }

before do
  allow_any_instance_of(ApplicationController)
    .to receive(:current_user)
    .and_return(suspended_user)
end
```

## Instance Method Stubs

Use `simple_stub_any_instance_of` for instance methods:

```ruby
simple_stub_any_instance_of(ApplicationController, :current_user) { user }
```

The stub affects existing instances and new instances of the target class until
teardown resets it. Method stubs are shared across Fibers and Threads, so a
stub applied by test setup is also visible to a Rails test server running in
another thread.

## Class Method Stubs

Use `simple_stub` for singleton methods, including class methods:

```ruby
class TimeFixture < Smartest::Fixture
  fixture :fixed_time do
    frozen_time = Time.utc(2026, 1, 1, 0, 0, 0)
    simple_stub(Time, :now) { frozen_time }
    frozen_time
  end
end

around_suite do |suite|
  use_fixture TimeFixture
  suite.run
end
```

```ruby
test("uses fixed time") do |fixed_time:|
  expect(Time.now).to eq(fixed_time)
end
```

## Optional Autouse-Style Setup From Hooks

Most method stubs should remain in fixtures. When a replacement is an
intentional rule for every applicable test and does not depend on fixture data,
you can put it in a hook instead. This is similar to a Pytest autouse fixture:
the setup applies without adding a fixture keyword to every test signature.

Use `around_test` when the replacement should be applied and reset for each
applicable test:

```ruby
around_test do |test|
  simple_stub(NotificationClient, :push) { :ok }
  test.run
end
```

Use `around_suite` when an external service should stay stubbed for the whole
suite:

```ruby
around_suite do |suite|
  simple_stub_any_instance_of(PaymentGateway, :charge) { :approved }
  suite.run
end
```

Call the stub helper before `suite.run` or `test.run`. Smartest resets the stub
when that hook invocation exits, including when the suite, test, or hook fails.
An `around_test` written directly in a test file applies to later tests in that
file. Register it inside `around_suite` when it should apply suite-wide.

Use this style for broad test-environment rules such as "never contact the
payment gateway." Keep scenario-specific or data-dependent stubs in fixtures so
their side effects remain visible at the test boundary.

## Constant Stubs

Use `with_stub_const` with a block for constants. It is available in test
bodies, `around_test`, and `around_suite`, not in fixture blocks.

```ruby
test("uses fake payment provider") do
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    expect(Checkout.call).to eq(:paid)
  end
end
```

If you are coming from RSpec, use Smartest's `around_test` where you would often
think of an around example hook:

```ruby
around_test do |test|
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    test.run
  end
end
```

Use `around_suite` when the constant should stay replaced for the whole suite
run:

```ruby
around_suite do |suite|
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    suite.run
  end
end
```

Constant stubs are process-global until the block exits.

## How Method Stub Teardown Works

You do not need to call `reset` manually when using method stub helpers inside
fixtures or hooks. The helper internally:

1. creates the stub state
2. applies the replacement
3. registers teardown to reset it

Conceptually, this:

```ruby
simple_stub_any_instance_of(ApplicationController, :current_user) { user }
```

behaves like applying a `Smartest::SimpleStub` and registering its `reset` with
the current fixture or hook teardown owner:

```ruby
stub = Smartest::SimpleStub.new(ApplicationController, :current_user) { user }
stub.apply
# The current fixture or hook scope registers: stub.reset
```

Teardown is tied to the scope that applies the stub:

- `fixture` method stubs reset after each test.
- `suite_fixture` method stubs reset after the suite fixture scope ends.
- `around_test` method stubs reset when that hook invocation exits.
- `around_suite` method stubs reset when that hook invocation exits.

Hook cleanup runs even when a test fails, is skipped from the hook, or a hook
fails to call its required run target.
If a test or hook and its method-stub cleanup both fail, Smartest preserves the
primary failure and reports the reset error separately as a teardown failure.

When method stubs for the same class and method overlap, the most recently
applied stub wins. Resetting that stub restores the previous stub instead of
resetting the whole stack. Hook, fixture, and suite fixture stubs can therefore
nest without discarding an outer replacement.

Prefer fixture-scoped stubs so the stubbed state stays explicit in a test's
keyword dependencies. Use hook-scoped stubs only for intentionally broad,
autouse-style setup that does not need fixture data.

## How Constant Stub Blocks Work

`with_stub_const` records the previous constant value, replaces it,
yields to the block, and restores or removes the constant with `ensure`.

Conceptually, this:

```ruby
with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
  call_api
end
```

behaves like:

```ruby
old_value = AppConfig.const_get(:PAYMENT_PROVIDER, false)
AppConfig.__send__(:remove_const, :PAYMENT_PROVIDER)
AppConfig.const_set(:PAYMENT_PROVIDER, "fake")

begin
  call_api
ensure
  AppConfig.__send__(:remove_const, :PAYMENT_PROVIDER)
  AppConfig.const_set(:PAYMENT_PROVIDER, old_value)
end
```

The real implementation uses `remove_const` and `const_set` so it can also
restore constants that did not exist before the block.

## API

`simple_stub_any_instance_of(klass, method_name) { ... }` stubs an instance
method on `klass`.

```ruby
simple_stub_any_instance_of(ApplicationController, :current_user) { user }
```

`simple_stub(object, method_name) { ... }` stubs a singleton method on `object`.
For class methods, pass the class object:

```ruby
simple_stub(Time, :now) { fixed_time }
```

`with_stub_const(constant_path, value) { ... }` stubs a constant for the
duration of the block. The path may be a String or Symbol:

```ruby
with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
  call_api
end
```

`simple_stub_any_instance_of` and `simple_stub` return the
`Smartest::SimpleStub` object. `with_stub_const` returns the block result.

`simple_stub_any_instance_of` and `simple_stub` are available inside
`Smartest::Fixture` fixture blocks, including `fixture` and `suite_fixture`, as
well as `around_test` and `around_suite`. They are not top-level DSL methods and
are not available in test bodies because method stubs require a teardown owner.
`with_stub_const` is available in test bodies, `around_test`, and
`around_suite`.

## What Stubs Are Not

Smartest stubs are not a mock framework. They do not:

- verify calls
- record arguments
- provide expectations

Use Smartest expectations for assertions.

## Low-Level API

Use `Smartest::SimpleStub` directly when you need to manage reset manually:

```ruby
stub = Smartest::SimpleStub.new(PaymentGateway, :charge) { :approved }
stub.apply
stub.reset
```

The first argument must be a `Class`, and the second argument must be a
`Symbol`. For singleton methods, pass the object's singleton class:

```ruby
stub = Smartest::SimpleStub.new(Time.singleton_class, :now) { fixed_time }
stub.apply
stub.reset
```

`apply` raises `Smartest::SimpleStub::AlreadyAppliedError` when the same stub
object is already applied. `reset` raises
`Smartest::SimpleStub::NotAppliedError` when that stub object is not applied.
Reset must be called on the stub object returned by the original setup.

## Scope and Concurrency

Smartest stubs are process-wide state. They are intended for serial test
execution and for cases like a Rails test server thread serving the current
test. They do not provide isolation for multi-threaded parallel test execution:
one test can observe or reset another test's method or constant stub.

`Smartest::SimpleStub` installs a process-wide dispatcher method and stores
active method stubs in a process-wide registry. Applying a stub changes behavior
in all Fibers and Threads until that stub is reset:

```ruby
stub = Smartest::SimpleStub.new(User, :name) { "Stubbed" }
stub.apply

User.new.name
# => "Stubbed"

Thread.new do
  User.new.name
  # => "Stubbed"
end.join

stub.reset
```

Method stubs for the same class and method are stacked. The newest applied stub
is used, and resetting it restores the previous stub. This stack is for
deliberately nested stub lifetimes, such as a test-scoped fixture temporarily
overriding a suite-scoped fixture.

Constant stubs are also process-global: `with_stub_const` replaces the constant
on the owner module until the block exits.
