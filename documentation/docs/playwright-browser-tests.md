---
title: Browser Tests With Playwright
description: Drive Playwright browser tests from Smartest fixtures.
---

# Browser Tests With Playwright

Smartest can generate a Playwright-focused browser-test scaffold. It keeps
browser resources as ordinary Smartest fixtures:

- the Playwright runtime is shared for the suite
- the browser process is shared for the suite
- each test gets a fresh browser context and page

## Install

Initialize the browser-test scaffold:

```bash
bundle exec smartest --init-browser
```

The init command runs the normal `smartest --init` scaffold, then:

- creates `smartest/fixtures/playwright_fixture.rb`
- creates `smartest/matchers/playwright_matcher.rb`
- creates `smartest/example_browser_test.rb`
- registers `PlaywrightFixture` and `PlaywrightMatcher`
- adds `gem "playwright-ruby-client", group: :test` to the Gemfile
- runs `bundle install`
- runs `npm init --yes` when no `package.json` exists yet
- runs `npm install playwright --save-dev`
- runs `./node_modules/.bin/playwright install`

## Generated Helper

The generated helper loads fixture and matcher files, then registers the
Playwright fixture and matcher:

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

`smartest --init-browser` generates the matcher module under
`smartest/matchers/`:

```ruby title="smartest/matchers/playwright_matcher.rb"
require "playwright"
require "playwright/test"

module PlaywrightMatcher
  include Playwright::Test::Matchers
end
```

`PlaywrightMatcher` includes `Playwright::Test::Matchers`, so Smartest
expectations can use Playwright assertions such as `have_url` and `have_text`.

## Generated Fixtures

The generated fixture class owns the browser lifecycle:

```ruby title="smartest/fixtures/playwright_fixture.rb"
require "playwright"

class PlaywrightFixture < Smartest::Fixture
  suite_fixture :playwright do
    runtime = Playwright.create(
      playwright_cli_executable_path: "./node_modules/.bin/playwright",
    )
    cleanup { runtime.stop }
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

Set `BROWSER=firefox` or `BROWSER=webkit` to use another browser type. Set
`HEADLESS=0` or `HEADLESS=false` to show the browser, and set `SLOW_MO=250` to
slow Playwright actions by 250 milliseconds.

## Generated Test

`smartest --init-browser` creates a browser test:

```ruby title="smartest/example_browser_test.rb"
require "test_helper"

test("finds the smartest gem on RubyGems") do |page:|
  page.goto("https://rubygems.org/")
  page.locator("input[name='query']").fill("smartest")
  page.keyboard.press("Enter")

  page.locator("a[href='/gems/smartest']").click
  expect(page).to have_url("https://rubygems.org/gems/smartest")
  expect(page.locator(".versions")).to have_text("0.3.0.alpha1")
end
```

Run the generated test by passing its path to the Smartest CLI:

```bash
bundle exec smartest smartest/example_browser_test.rb
```

![Playwright browser test running from Smartest](/img/playwright-browser-tests.gif)
