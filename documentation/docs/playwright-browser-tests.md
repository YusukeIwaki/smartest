---
title: Browser Tests With Playwright
description: Drive Playwright browser tests from Smartest fixtures.
---

# Browser Tests With Playwright

Smartest does not need a separate browser-test API. Browser resources can be
plain fixtures, and each test can request the Playwright `page` it needs with a
keyword argument.

This page assumes you understand the fixture model from [Fixtures](./fixtures.md):

- use `suite_fixture` for expensive resources shared by the whole suite
- use `fixture` for values that should be fresh for each test
- use `cleanup` to release the resource owned by that fixture

That maps naturally to Playwright:

- the Playwright runtime is shared for the suite
- the browser process is shared for the suite
- each test gets a fresh browser context and page

## Install Dependencies

Add Smartest and the Playwright Ruby client to the Gemfile:

```ruby {4} title="Gemfile"
source "https://rubygems.org"

gem "smartest"
gem "playwright-ruby-client"
```

Add Playwright to `package.json` so the local Playwright CLI is available:

```json title="package.json"
{
  "dependencies": {
    "playwright": "^1.59.1"
  }
}
```

Install the dependencies and download Chromium:

```bash
bundle install
npm install
npx playwright install chromium
```

## Load Playwright

Require Playwright from `smartest/test_helper.rb` before loading fixture files:

```ruby {2} title="smartest/test_helper.rb"
require "smartest/autorun"
require "playwright"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

use_fixture PlaywrightFixture
```

The generated helper already loads every file under `smartest/fixtures/`, so the
Playwright fixture can live with the rest of the suite setup. Register it from
the helper so every browser test can request `page:`.

## Define Playwright Fixtures

Put the browser lifecycle in a fixture class:

```ruby title="smartest/fixtures/playwright_fixture.rb"
class PlaywrightFixture < Smartest::Fixture
  suite_fixture :playwright do
    runtime = Playwright.create(
      playwright_cli_executable_path: "./node_modules/.bin/playwright",
    )

    cleanup { runtime.stop }
    runtime.playwright
  end

  suite_fixture :browser do |playwright:|
    browser = playwright.chromium.launch(headless: true)
    cleanup { browser.close }
    browser
  end

  fixture :page do |browser:|
    context = browser.new_context
    cleanup { context.close }
    context.new_page
  end
end
```

The dependency chain is expressed with keyword arguments:

- `browser` depends on `playwright:`
- `page` depends on `browser:`
- tests depend on `page:`

Smartest resolves that chain automatically. When a test asks for `page:`, it
resolves `page`, then `browser`, then `playwright`.

The two suite fixtures make browser startup cheap across the suite. The
test-scoped `page` fixture creates a new browser context for each test, so
cookies, local storage, and session state do not leak between tests.

Cleanup follows the same scopes. Each test closes its browser context after the
test finishes. After the full suite finishes, Smartest closes the browser and
stops the Playwright runtime.

## Write a Browser Test

Request `page:` from the test file:

```ruby title="smartest/rubygems_search_test.rb"
require "test_helper"

test("finds the smartest gem on RubyGems") do |page:|
  page.goto("https://rubygems.org/")
  page.locator("input[name='query']").first.fill("smartest")
  page.keyboard.press("Enter")
  page.wait_for_url(%r{/search})

  page.locator("a[href='/gems/smartest']").first.click
  page.wait_for_url("https://rubygems.org/gems/smartest")

  owner_href = page.locator("a[href^='/profiles/']").first.get_attribute("href")
  expect(owner_href).to eq("/profiles/YusukeIwaki")
end
```

The test body receives an ordinary Playwright `Page` object. All navigation,
locator, keyboard, and assertion setup can use the Playwright Ruby client API
directly.

## Run the Suite

Run browser tests the same way as any other Smartest suite:

```bash
bundle exec smartest
```

Because the test file requires `test_helper`, Smartest loads the Playwright
fixture file, registers `PlaywrightFixture` from the helper, resolves `page:`,
and runs the test.

![Playwright browser test running from Smartest](/img/playwright-browser-tests.gif)
