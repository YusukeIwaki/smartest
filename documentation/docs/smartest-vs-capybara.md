---
title: Smartest vs Capybara
sidebar_label: vs Capybara
description: Compare Capybara-driven Rails system tests with Smartest's Playwright + pytest-style fixture model. Keep Capybara for simple flows; migrate stability-critical tests to Smartest.
---

# Smartest vs Capybara

Capybara is a brilliant pillar of Rails browser testing. One DSL — `visit`,
`click_button`, `assert_selector` — covers a huge range of edge-case browser
scenarios, and you can swap the underlying browser by changing the driver
(Selenium, capybara-playwright-driver, and more).

The friction shows up on async-heavy modern pages: SPAs, Turbo Streams, modal
animations, "wait until the loading spinner disappears." Tests get flaky, and
tuning Capybara waits to fix them becomes ongoing maintenance.

The recommended escape hatch is `capybara-playwright-driver`'s
`with_playwright_page`, which exposes a real Playwright `Page` and Playwright
web-first assertions inside a block. That block solves the stability problem,
but the resulting nested-callback style feels disproportionate when all you
wanted was a slightly more stable browser test.

Smartest replaces the Capybara-based stack entirely. Thanks to pytest-style
fixtures, writing `|page:|` is enough to get a Playwright `Page` already wired
for browser testing — web-first assertions just work, with no wrapper to opt
into. Because Smartest does not load `spec/` or `test/`, it coexists with your
existing Capybara suite, so migration can be gradual rather than a rewrite.

## At a Glance

| Concern | Capybara | Smartest |
| --- | --- | --- |
| Browser API | DSL: `visit`, `fill_in`, `click_button`, `assert_selector` | Playwright: `page.goto`, `page.get_by_role`, `expect(page).to have_text` |
| Wait strategy | Implicit Capybara waits, tunable with `using_wait_time` | Playwright web-first assertions retry until match |
| Browser drivers | Swap drivers (Selenium, capybara-playwright-driver, …) | Direct Playwright via `playwright-ruby-client` |
| Access to raw Playwright | `page.driver.with_playwright_page do \|p\| ... end` block | Just `page:` keyword fixture, always a Playwright `Page` |
| Test setup | RSpec `let` / `before`, Minitest `setup` | Class-based fixtures requested by keyword |
| Best fit | Simple synchronous flows | Async-heavy pages where stability and customization matter |

## When Capybara still wins

For a synchronous flow with no async surprises — a login form, a checkout that
posts and redirects, a settings page that re-renders the whole document —
Capybara is excellent and Smartest does not give you enough leverage to justify
a rewrite.

```ruby title="Capybara"
scenario "a user logs in" do
  visit new_session_path
  fill_in "Email", with: "alice@example.com"
  fill_in "Password", with: "secret"
  click_button "Log in"

  expect(page).to have_content("Welcome, Alice")
end
```

This test is short, the DSL reads naturally, and there is little async timing
for waits to get wrong. Keep it.

## When Smartest pays off

The case for migrating shows up when stability matters beyond Capybara's
defaults — modal animations, network-driven content, Turbo Streams, SPA
routing, push notifications, retried polls. Inside `capybara-playwright-driver`,
the recommended response is to drop into a Playwright `Page` with
`with_playwright_page`:

```ruby title="Capybara + capybara-playwright-driver"
scenario "the user sees the new comment after submission" do
  visit post_path(post)

  page.driver.with_playwright_page do |playwright_page|
    playwright_page.locator("textarea[name='comment']").fill("Looks good")
    playwright_page.locator("button[type='submit']").click
    playwright_page.locator(".toast--success").wait_for(state: "visible")

    expect(playwright_page.get_by_text("Looks good")).to be_visible
  end
end
```

This works, but the test now lives inside a nested callback. Some lines speak
Capybara (`visit`, `page.driver`), others speak Playwright
(`playwright_page....`), and you have to remember which side you are on.
Window resize becomes
`Capybara.current_session.driver.resize_window_to(...)`. Methods don't always
map cleanly (`click_button` becomes `click_on`). Every test that needs
stability acquires another layer of nesting.

In Smartest the same scenario is written directly against a Playwright `Page`,
with no `with_playwright_page` wrapper:

```ruby title="Smartest"
test("the user sees the new comment after submission") do |page:, post:|
  page.goto(post_path(post))

  page.locator("textarea[name='comment']").fill("Looks good")
  page.locator("button[type='submit']").click

  expect(page.locator(".toast--success")).to be_visible
  expect(page.get_by_text("Looks good")).to be_visible
end
```

`page` is a Playwright `Page`, supplied by the generated `RailsSystemTestFixture`
(see [Test a Rails app locally](./rails-browser-tests.md)). Web-first
assertions like `have_text` and `be_visible` retry until the page reaches the
asserted state — which is exactly what auto-waiting gave you inside
`with_playwright_page`, without the wrapper.

## DSL Reference

The browser API translates one-to-one between the two stacks:

| Capybara | Smartest + Playwright |
| --- | --- |
| `visit root_path` | `page.goto("/")` |
| `fill_in "Email", with: user.email` | `page.get_by_label("Email").fill(user.email)` |
| `click_button "Log in"` | `page.get_by_role("button", name: "Log in").click` |
| `click_link "Profile"` | `page.get_by_role("link", name: "Profile").click` |
| `assert_text "Dashboard"` | `expect(page.get_by_text("Dashboard")).to be_visible` |
| `assert_selector "h1", text: "Users"` | `expect(page.locator("h1")).to have_text("Users")` |
| `assert_no_text "Error"` | `expect(page.get_by_text("Error")).not_to be_visible` |
| `assert_current_path "/dashboard"` | `expect(page).to have_url(/\/dashboard\z/)` |
| `using_wait_time(10) { ... }` | Web-first assertions auto-retry; tune the Playwright `expect` timeout |
| `Capybara.current_session.driver.resize_window_to(1280, 800)` | `page.set_viewport_size(width: 1280, height: 800)` |

## Test setup and stubbing

Capybara tests typically share state through RSpec `let` / `before`:

```ruby title="Capybara + RSpec"
let(:suspended_user) { create(:user, :suspended) }

before do
  allow_any_instance_of(ApplicationController)
    .to receive(:current_user)
    .and_return(suspended_user)
end

scenario "suspended user sees account restriction page" do
  visit dashboard_path
  expect(page).to have_content("Your account is suspended")
end
```

In Smartest the setup is a fixture and a stub, and the test declares the
fixture it depends on:

```ruby title="Smartest"
class ApplicationSystemFixture < Smartest::Fixture
  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :suspended_user_page do |page:, suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) do
      suspended_user
    end
    page
  end
end

test("suspended user sees account restriction page") do |suspended_user_page:|
  suspended_user_page.goto("/dashboard")
  expect(suspended_user_page.get_by_text("Your account is suspended")).to be_visible
end
```

The dependency is visible at the test boundary, and Smartest resets the stub
during fixture teardown.

## When Smartest is a good fit

Smartest is worth considering when:

- existing system tests are flaky on async-heavy pages and Capybara waits are hard to tune
- you already reach for `with_playwright_page` in many tests
- you want Playwright web-first assertions to be the default, not a wrapper
- setup dependencies should be visible at the test boundary

Capybara may stay the better fit when:

- tests are short, synchronous flows where the DSL reads naturally
- the team prefers `visit` / `fill_in` / `assert_selector` and is not hitting flakiness
- the suite leans on Capybara-specific helpers, drivers, or matchers you do not want to replace

## Moving One Test at a Time

Smartest does not load `spec/` or `test/`, so Capybara-based system tests stay
where they are. Add Smartest tests under `smartest/`, and start by moving just
the tests that hurt:

```text
spec/system/
  login_spec.rb              ← stays in Capybara
  dashboard_spec.rb          ← stays in Capybara
smartest/
  test_helper.rb
  fixtures/
    rails_system_fixture.rb
    application_system_fixture.rb
  comment_submission_test.rb ← rewritten in Smartest
  push_failure_test.rb       ← rewritten in Smartest
```

Move the most fragile tests first. The login flow can stay in Capybara
indefinitely.
