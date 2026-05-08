---
title: Test a Rails app with Docker
description: Run Smartest Rails browser tests from a Rails app container while Chromium, Firefox, or WebKit run in a Playwright sidecar container.
---

# Test a Rails app with Docker

Rails apps often run inside Docker in development and CI. Installing browser
dependencies into that app image can make it large and fragile, especially with
Alpine-based images. Smartest keeps the Rails test server in the Rails Ruby
process and moves only Playwright's browser runtime into a sidecar container.

That means FactoryBot, ActiveRecord, Rails helpers, and Smartest method stubs
still run in the test process, while the browser itself runs in the Playwright
container.

## Quick start

Generate the Rails browser-test scaffold without downloading browser binaries
into the Rails app container:

```bash
SMARTEST_SKIP_BROWSER_DOWNLOAD=1 bundle exec smartest --init-rails
```

This still creates the Rails fixture, Playwright matcher, example test, Gemfile
entry, and Playwright npm package. It skips only
`./node_modules/.bin/playwright install`.

Run the suite with a Playwright server URL and a Rails URL that the browser can
reach from the Docker network:

```bash
PLAYWRIGHT_WS_ENDPOINT=ws://playwright:3000/ \
SMARTEST_RAILS_TEST_SERVER_HOST=0.0.0.0 \
SMARTEST_RAILS_TEST_SERVER_PORT=4001 \
SMARTEST_RAILS_BASE_URL=http://app:4001 \
bundle exec smartest smartest/
```

There is no separate `--browser=docker` or `--skip-browser-install` option. The
same generated fixture supports local and Docker runs through environment
variables.

## Architecture

In the Rails app container:

- Smartest runs the test suite.
- Rails boots in `RAILS_ENV=test`.
- `Smartest::Rails::TestServer` starts `Rails.application` in the same Ruby
  process.
- Fixtures create records, install stubs, and prepare application state.

In the Playwright sidecar container:

- Playwright server listens on a WebSocket endpoint.
- Browser processes run with the dependencies from the official Playwright
  image.

Keep the Rails server in the Smartest process. Starting Rails separately with
`bin/rails server -e test` prevents Ruby-side method stubs from affecting the
requests that the browser makes.

## Docker Compose example

```yaml title="compose.yml"
services:
  app:
    build: .
    command: bundle exec smartest smartest/
    environment:
      RAILS_ENV: test
      RACK_ENV: test

      PLAYWRIGHT_WS_ENDPOINT: ws://playwright:3000/
      SMARTEST_RAILS_TEST_SERVER_HOST: 0.0.0.0
      SMARTEST_RAILS_TEST_SERVER_PORT: 4001
      SMARTEST_RAILS_BASE_URL: http://app:4001

      BROWSER: chromium
      HEADLESS: "true"
    depends_on:
      - playwright

  playwright:
    image: mcr.microsoft.com/playwright:v1.50.1-noble
    init: true
    ipc: host
    working_dir: /home/pwuser
    user: pwuser
    command: >
      /bin/sh -c "npx -y playwright@1.50.1 run-server --port 3000 --host 0.0.0.0"
```

Use your own service name if it is not `app`; `SMARTEST_RAILS_BASE_URL` must use
the host name that the Playwright container can resolve on the Compose network.

## Environment variables

| Variable | When used | Purpose |
| --- | --- | --- |
| `SMARTEST_SKIP_BROWSER_DOWNLOAD` | During `--init-rails` | Skip browser binary installation in the Rails app container. Truthy values include `1`, `true`, and `yes`. |
| `PLAYWRIGHT_WS_ENDPOINT` | During test execution | Connect the generated fixture to a remote Playwright server instead of starting local Playwright. |
| `SMARTEST_RAILS_TEST_SERVER_HOST` | During test execution | Bind the Rails test server to a host visible from the Docker network. Use `0.0.0.0` for Compose sidecars. |
| `SMARTEST_RAILS_TEST_SERVER_PORT` | During test execution | Use a fixed Rails test-server port. |
| `SMARTEST_RAILS_BASE_URL` | During test execution | Set the URL that browser code uses as Playwright's `baseURL`. |
| `BROWSER` | During test execution | Choose `chromium`, `firefox`, or `webkit`. |
| `HEADLESS` | During test execution | Set `0` or `false` for headed local runs. |

`SMARTEST_SKIP_BROWSER_DOWNLOAD` and `PLAYWRIGHT_WS_ENDPOINT` are deliberately
separate. The first affects scaffold initialization; the second chooses remote
Playwright at test runtime.

## The 127.0.0.1 problem

In local mode, `127.0.0.1` points at the machine running both Rails and the
browser.

In Docker sidecar mode, the browser runs inside the Playwright container. From
that browser's point of view, `127.0.0.1` is the Playwright container, not the
Rails app container.

Use all three Rails server variables together:

```bash
SMARTEST_RAILS_TEST_SERVER_HOST=0.0.0.0
SMARTEST_RAILS_TEST_SERVER_PORT=4001
SMARTEST_RAILS_BASE_URL=http://app:4001
```

The generated fixture binds Rails to `0.0.0.0`, waits for readiness from inside
the app container, and gives Playwright `http://app:4001` as the browser-visible
base URL.

## Version matching

Keep the Playwright server version in the sidecar aligned with the version
expected by `playwright-ruby-client` in the Rails app container.

After bundle install, you can print the expected Playwright version with:

```bash
ruby -rplaywright -e 'puts Playwright::COMPATIBLE_PLAYWRIGHT_VERSION'
```

Use that version in both the Docker image tag and the `npx playwright@...`
command when possible.

## When local mode is simpler

Use the local setup from [Test a Rails app locally](./rails-browser-tests.md)
when the Rails app runs directly on your development machine and installing
browser dependencies there is acceptable. Docker sidecar mode is most useful
when the Rails app itself already runs in Docker, the app image is Alpine-based,
or CI should keep browser dependencies outside the Rails image.

## Summary

Docker sidecar mode changes where the browser runs, not where Rails test state
lives. Smartest still starts Rails in the test process, fixtures still build
application state from Ruby, and Playwright still drives a real browser through
the generated `page:` fixture.
