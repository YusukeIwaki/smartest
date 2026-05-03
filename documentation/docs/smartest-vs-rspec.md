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
| Teardown | `after` hooks or helper-owned cleanup | `cleanup` inside the fixture that owns the resource |
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

## Resource Cleanup

RSpec can clean up resources with hooks. Smartest puts cleanup next to the
resource acquisition:

```ruby title="Smartest"
class WebFixture < Smartest::Fixture
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

This keeps lifecycle ownership local. The fixture that starts `server` also
registers the cleanup for `server`.

## When Smartest Is a Good Fit

Smartest is worth considering when:

- tests have setup dependencies that should be visible at the test boundary
- one fixture naturally depends on another fixture
- cleanup should live beside the resource setup
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
