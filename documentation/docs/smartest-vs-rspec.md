---
title: Smartest vs RSpec
description: Compare Smartest's explicit keyword fixture injection with RSpec let, before hooks, examples, and teardown.
---

# Smartest vs RSpec

RSpec is a mature Ruby testing framework with a broad BDD DSL, nested example
groups, shared examples, metadata, and a large matcher ecosystem.

Smartest is smaller and more focused. It is designed for tests where setup
dependencies should be visible in the test signature and fixture dependency
graph.

## At a Glance

| Concern | RSpec | Smartest |
| --- | --- | --- |
| Test shape | `describe` / `context` / `it` blocks | Top-level `test("name")` blocks |
| Reusable setup | `let`, `let!`, `before`, helper methods | Class-based fixtures |
| Dependency visibility | Examples call helper methods from the body | Tests request fixtures with keyword arguments |
| Setup dependencies | Often expressed by one `let` calling another | Fixture block keyword arguments |
| Teardown | `after` hooks or helper-owned teardown | `on_teardown` inside the fixture that owns the resource |
| Best fit | Rich BDD structure and RSpec ecosystem | Explicit pytest-style fixture injection |

## `let` Compared With Keyword Fixtures

RSpec `let` is useful when examples need lazy helper methods:

```ruby title="RSpec"
RSpec.describe UserMailer do
  let(:user) { User.new(name: "Alice") }
  let(:mailer) { UserMailer.new(user) }

  it "renders the subject" do
    expect(mailer.subject).to eq("Welcome, Alice")
  end
end
```

In Smartest, fixtures live in a `Smartest::Fixture` subclass and tests request
them with required keyword arguments:

```ruby title="Smartest"
class MailerFixture < Smartest::Fixture
  fixture :user do
    User.new(name: "Alice")
  end

  fixture :mailer do |user:|
    UserMailer.new(user)
  end
end

around_suite do |suite|
  use_fixture MailerFixture
  suite.run
end

test("renders the subject") do |mailer:|
  expect(mailer.subject).to eq("Welcome, Alice")
end
```

The Smartest test signature shows that the test depends on `mailer`. The
`mailer` fixture signature shows that it depends on `user`.

## Resource Teardown

RSpec can clean up resources with hooks. Smartest puts teardown next to the
resource acquisition:

```ruby title="Smartest"
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    on_teardown { server.stop }
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

This keeps lifecycle ownership local. The fixture that starts `server` also
registers the teardown for `server`.

## Method Stubs

RSpec method stubs often live in `before` hooks:

```ruby title="RSpec"
RSpec.describe Checkout do
  let(:fixed_now) { Time.utc(2026, 1, 1, 0, 0, 0) }

  before do
    allow(Time).to receive(:now).and_return(fixed_now)
  end

  it "uses the fixed time" do
    expect(Checkout.call.created_at).to eq(fixed_now)
  end
end
```

In Smartest, put the stub in a fixture and request that fixture from tests that
depend on it:

```ruby title="Smartest"
class TimeFixture < Smartest::Fixture
  fixture :fixed_now do
    fixed_now = Time.utc(2026, 1, 1, 0, 0, 0)
    simple_stub(Time, :now) { fixed_now }
    fixed_now
  end
end

around_suite do |suite|
  use_fixture TimeFixture
  suite.run
end

test("uses the fixed time") do |fixed_now:|
  expect(Checkout.call.created_at).to eq(fixed_now)
end
```

The fixture signature makes the stubbed dependency explicit, and Smartest resets
the method stub from fixture teardown.

For `allow_any_instance_of`, use `simple_stub_any_instance_of`:

```ruby title="RSpec"
before do
  allow_any_instance_of(ApplicationController)
    .to receive(:current_user)
    .and_return(user1)
end
```

```ruby title="Smartest"
class AuthFixture < Smartest::Fixture
  fixture :user1 do
    create(:user)
  end

  fixture :logged_in_as_user1 do |user1:|
    simple_stub_any_instance_of(ApplicationController, :current_user) { user1 }
    user1
  end
end

test("uses the current user") do |logged_in_as_user1:|
  expect(call_api.user).to eq(logged_in_as_user1)
end
```

Constant stubs are different from method stubs. Use `with_stub_const` with a
block in a test body, `around_test`, or `around_suite`; it is intentionally not
a fixture helper because Ruby constants are process-global:

```ruby title="Smartest"
test("uses fake payment provider") do
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    expect(Checkout.call).to eq(:paid)
  end
end
```

## When Smartest Is a Good Fit

Smartest is worth considering when:

- tests have setup dependencies that should be visible at the test boundary
- one fixture naturally depends on another fixture
- teardown should live beside the resource setup
- you want a small runner with pytest-style fixture injection for Ruby

RSpec may be a better fit when:

- the suite relies heavily on nested `describe` and `context` structure
- shared examples, metadata, or RSpec-specific integrations are central
- the team already benefits from RSpec's matcher and extension ecosystem

## Moving One Test at a Time

Smartest does not load `test/` or `spec/` by default. A project can keep RSpec
tests in `spec/` while adding Smartest tests under `smartest/`:

```text
spec/
  user_mailer_spec.rb
smartest/
  test_helper.rb
  fixtures/
    mailer_fixture.rb
  user_mailer_test.rb
```

Start by moving one setup concept into a fixture class, register it with
`use_fixture`, then make the test request only the fixtures it needs.
