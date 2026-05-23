---
title: Why Smartest browser tests
description: Why Smartest exists for Ruby browser testing, and how pytest-style fixtures change the setup.
---

# Why Smartest browser tests

Smartest is invented to make Ruby browser testing **smarter**, not just slightly nicer.

The direct inspiration is Playwright Test: its authors built a dedicated test runner instead of writing yet another Jest plugin, because browser testing is a different domain from unit testing — not just unit testing with a browser bolted on top. Smartest brings that same move to Ruby. Rather than plug Playwright into RSpec or Minitest, it rebuilds the runner around pytest-style fixtures so that the Playwright runtime, browser, and page lifecycles are expressed directly in each test's signature. See [Introducing pytest-style fixtures into Ruby for smarter browser testing](https://dev.to/yusukeiwaki/introducing-pytest-style-fixtures-into-ruby-for-smarter-browser-testing-lbi) for the longer story.

In practice this means you stay in Ruby: each browser test receives a `page:`
fixture and drives it with the full Playwright API. Smartest scaffolds the
setup for you, and the four steps below take you from zero to a passing
browser test.

## Quick Start

### 1. Initialize the scaffold

```bash
bundle exec smartest --init-browser
```

This sets up everything needed to run Playwright browser tests. If your
Gemfile was created with `bundle init`, Smartest keeps or adds `gem "smartest"`,
adds the `playwright-ruby-client` gem, installs the Playwright Node.js package
and browsers, and creates example fixture / matcher / test files under
`smartest/`.

### 2. Run the generated example test

```bash
bundle exec smartest smartest/example_browser_test.rb
```

![Playwright browser test running from Smartest](/img/playwright-browser-tests.gif)

### 3. Write your own browser test

Inside any test file under `smartest/`, declare a test that takes the `page:`
fixture. `page` is a Playwright `Page`, so the full Playwright Ruby API is
available. Smartest expectations support Playwright matchers like `have_url`
and `have_text`.

```ruby title="smartest/example_browser_test.rb"
require "test_helper"

test("finds the smartest gem on RubyGems") do |page:|
  page.goto("https://rubygems.org/")
  page.locator("input[name='query']").fill("smartest")
  page.keyboard.press("Enter")

  page.locator("a[href='/gems/smartest']").click
  expect(page).to have_url("https://rubygems.org/gems/smartest")
  expect(page.locator("h1")).to have_text("smartest")
end
```

Each test gets a fresh browser context and page; the Playwright runtime and
browser process are shared across the suite.

### 4. Control the browser via environment variables

The scaffold reads three environment variables at launch time:

| Variable   | Values                      | Effect                                                     |
| ---------- | --------------------------- | ---------------------------------------------------------- |
| `BROWSER`  | `chromium` (default), `firefox`, `webkit` | Which browser type to launch.                  |
| `HEADLESS` | `1` / `true` (default), `0` / `false`     | Set to `0` or `false` to show the browser window. |
| `SLOW_MO`  | integer (milliseconds)      | Slow each Playwright action by N ms. `0` (default) disables it. |

Examples:

```bash
# Run with Firefox
BROWSER=firefox bundle exec smartest smartest/example_browser_test.rb

# Show the browser and slow it down so you can watch the test
HEADLESS=0 SLOW_MO=250 bundle exec smartest smartest/example_browser_test.rb
```

That's everything you need to start writing browser tests. The rest of this
page explains what the scaffold generated and how to tune it.

---

## How it works

`smartest --init-browser` generates three Ruby files. They are ordinary
Smartest fixtures and matchers — edit them freely to tune behavior.

### What `--init-browser` generates

On top of the normal `smartest --init` scaffold, the command:

- creates `smartest/fixtures/playwright_fixture.rb`
- creates `smartest/matchers/playwright_matcher.rb`
- creates `smartest/example_browser_test.rb`
- registers `PlaywrightFixture` and `PlaywrightMatcher` in `test_helper.rb`
- keeps or adds `gem "smartest"` in the Gemfile
- adds `gem "playwright-ruby-client", group: :test` to the Gemfile and runs `bundle install`
- runs `npm init --yes` when no `package.json` exists yet
- runs `npm install playwright --save-dev`
- runs `./node_modules/.bin/playwright install`

### Test helper

The generated helper loads fixture and matcher files, then registers the
Playwright fixture and matcher for the suite:

```ruby {13-14} title="smartest/test_helper.rb"
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each do |matcher_file|
  require matcher_file
end

around_suite do |suite|
  use_matcher PredicateMatcher
  use_fixture PlaywrightFixture
  use_matcher PlaywrightMatcher
  suite.run
end
```

Add your own fixtures or matchers here, or replace `PlaywrightFixture` /
`PlaywrightMatcher` with subclasses of your own.

### Browser lifecycle fixture

The fixture class owns the Playwright runtime, the browser process, and the
per-test page. This is where the `BROWSER` / `HEADLESS` / `SLOW_MO`
environment variables are read — change this file to add launch options
(viewport size, locale, custom args, …) or to change the per-test context
(authentication state, recorded videos, …).

```ruby title="smartest/fixtures/playwright_fixture.rb"
require "playwright"

class PlaywrightFixture < Smartest::Fixture
  suite_fixture :playwright do
    runtime = Playwright.create(
      playwright_cli_executable_path: "./node_modules/.bin/playwright",
    )
    on_teardown { runtime.stop }
    runtime.playwright
  end

  suite_fixture :browser do |playwright:|
    browser_type = case ENV["BROWSER"]
    when "firefox"
      :firefox
    when "webkit"
      :webkit
    else
      :chromium
    end

    launch_options = {}
    launch_options[:headless] = !%w[0 false].include?(ENV["HEADLESS"])
    if (slow_mo = ENV["SLOW_MO"].to_i) > 0
      launch_options[:slowMo] = slow_mo
    end

    browser = playwright.send(browser_type).launch(**launch_options)
    on_teardown { browser.close }
    browser
  end

  fixture :page do |browser:|
    context = browser.new_context
    on_teardown { context.close }
    context.new_page
  end
end
```

Lifecycle summary:

- `:playwright` and `:browser` are `suite_fixture`s — created once and reused.
- `:page` is a regular `fixture` — created fresh for each test, with its own
  `BrowserContext` so cookies and storage are isolated.

### Playwright matcher

The matcher module exposes Playwright's web-first assertions (`have_url`,
`have_text`, `be_visible`, …) to Smartest's `expect(...).to ...` syntax:

```ruby title="smartest/matchers/playwright_matcher.rb"
require "playwright"
require "playwright/test"

module PlaywrightMatcher
  include Playwright::Test::Matchers
end
```

Add your own matcher methods to this module if you want project-specific
assertions on Playwright objects.
