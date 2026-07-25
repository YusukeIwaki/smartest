# Documentation Editorial Conventions

This file captures the framing and structure conventions for the Docusaurus
site under `documentation/`. The goal is to keep the docs consistent without
re-deciding the same questions each time.

- For build / deploy instructions, see `README.md` in this directory.
- For the rule that implementation changes must update docs in the same PR,
  see the top-level `AGENTS.md`.

## What Smartest is — the framing to assume

Smartest is a Ruby test runner whose purpose is **smarter Ruby browser
testing**, not a slightly nicer RSpec alternative. The library exists because:

- Mainstream Ruby browser testing today is unit-test-era architecture
  (RSpec / Minitest) with browser automation (Capybara / Playwright) bolted
  on top.
- Playwright Test changed the test runner because the target domain changed —
  browser testing is not unit testing. Smartest applies that same lesson to
  Ruby.
- Pytest-style fixture injection happens to be the cleanest way to express
  what a browser test actually depends on (server, browser, page, app state,
  stubs, route helpers, …) at the test signature.

When a page assumes a reader who is "considering Smartest", assume that
reader is feeling pain in their existing Rails browser-test suite — flaky
async tests, hard-to-customize Capybara waits, hidden setup — not someone
shopping for a new unit-test runner. Pages do **not** need to re-establish
this framing every time; link to `intro.md` (Why Smartest) or
`playwright-browser-tests.md` (Why Smartest browser tests) instead.

## Sidebar structure

The sidebar is grouped by reader goal, not by feature surface area. The shape
is modeled after the Vitest guide:

```
Introduction
  Why Smartest
  Getting Started
Learn
  Writing Tests
  Fixtures
  Stubs
  Matchers
  Helpers
  Skipping Tests
  Running Tests
Browser Tests
  Why Smartest browser tests       ← entry / positioning
  Test a Rails app locally
  Test a Rails app with Docker
Comparisons
  vs Pytest
  vs RSpec
  vs Minitest
  vs Capybara
Reference
  Errors
```

Top-level categories should answer "what reader goal is this for?", not
"what Smartest concept is this?". Keep new pages aligned with this shape.

## Page roles — primary purpose per page

| Page | Primary purpose |
| --- | --- |
| `intro.md` (Why Smartest) | Why Smartest exists at the project level. Sets the framing for the whole site. |
| `getting-started.md` | Smallest runnable test, end-to-end. |
| `writing-tests.md` | Test definition, expectations, basic structure. |
| `running-test-suites.md` (Running Tests) | `autorun` and the CLI. |
| `skipping-tests.md` | `skip` / `pending`. |
| `fixtures.md` | The class-based fixture model in depth — test-scoped, suite-scoped, dependencies, teardown. |
| `stubs.md` | Fixture-scoped method stubs, plus optional autouse-style hook setup, with automatic teardown. |
| `matchers.md` | Built-in and custom matchers. |
| `helpers.md` | Registering helper modules via `around_test`. |
| `playwright-browser-tests.md` (Why Smartest browser tests) | Browser Tests entry. Why-style positioning followed by Quick Start and "How it works" for the generic Playwright scaffold. |
| `rails-browser-tests.md` (Test a Rails app locally) | Concrete how-to for Rails browser tests against a local in-process Rails server. Aimed at engineers feeling Rails system-test pain. |
| `rails-browser-tests-with-docker.md` (Test a Rails app with Docker) | Concrete how-to for Rails browser tests where Smartest runs in the Rails app container and browsers run in a Playwright sidecar container. |
| `pytest-style-fixtures-for-ruby.md` (vs Pytest) | Comparison only. Map pytest concepts to Smartest. |
| `smartest-vs-rspec.md` (vs RSpec) | Comparison only. RSpec `let` / `before` → Smartest fixtures. |
| `smartest-vs-minitest.md` (vs Minitest) | Comparison only. Minitest setup / teardown → Smartest fixtures. |
| `smartest-vs-capybara.md` (vs Capybara) | Comparison. When to keep Capybara (simple synchronous flows, login forms) vs when migrating pays off (async-heavy stability-critical tests). Frames `with_playwright_page` as the awkward escape hatch Smartest replaces. |
| `reference/errors.md` | Reference for Smartest error classes. |

When the role of a page is ambiguous, prefer **role-by-reader-goal** over
**role-by-API-coverage**. A reader landing on the page should immediately
know what question this page answers for them.

## Title, sidebar label, and description

Three frontmatter fields are deliberately decoupled:

- `title:` — the `<title>` tag, the page `<h1>`, and (by default) the
  sidebar entry. Keep it concrete and short. **Do not stuff SEO keywords
  here.** Past mistake we have already corrected: titles like
  *"Pytest-style Fixtures in Ruby"* or *"Playwright-style Browser Tests in
  Ruby"* — never bring those back.
- `sidebar_label:` — set this **only** when the sidebar entry should be
  shorter than the page title. Currently used for `vs Pytest`, `vs RSpec`,
  `vs Minitest`, `vs Capybara`. For pages whose title is already short
  (e.g. `Fixtures`, `Stubs`), omit `sidebar_label`.
- `description:` — `<meta name="description">`. This is where SEO phrasing
  goes. Aim for one full sentence that names the feature *and* the
  user-facing benefit.

When adding a page: write the `<h1>` first, copy it into `title:`, write a
focused `description:`, and add `sidebar_label:` only if the sidebar context
genuinely shortens the label.

## Tone and structure conventions

- **Lead with positioning, not API coverage.** Browser-tests pages and
  comparison pages start with a paragraph that names a real reader pain
  point and how Smartest responds to it. Save API surface for later
  sections.
- **One Why per page.** If a page already has a Why-style intro at the top,
  do not add a second `## Why ...` section in the body. The
  Playwright-browser-tests page used to have both, and the second one
  disoriented first-time readers.
- **First-time-reader flow.** Browser-tests and Rails how-to pages should
  flow Why → Quick Start (or comparable lead-in) → How it works → Reference,
  in that order. Customization / advanced material lives at the end.
- **Scenario titles for "how-to" pages, not technology names.** A page that
  helps a reader test their local Rails app is titled
  *"Test a Rails app locally"*, not *"Rails"*. The Browser Tests sidebar
  entries follow this pattern.

## Page-overlap warning: Test a Rails app locally vs vs Capybara

`rails-browser-tests.md` (Test a Rails app locally) and
`smartest-vs-capybara.md` (vs Capybara) discuss overlapping subject matter
— Rails system tests, Capybara, Playwright, fixture-driven setup. Their
roles are different and must stay different:

- **Test a Rails app locally** is a *how-to*. The reader has already
  decided to try Smartest on a Rails app and needs to scaffold, run, write,
  and debug. The page may briefly motivate Smartest, but its bulk is
  concrete Rails setup — fixtures, database cleanup, port settings,
  troubleshooting.
- **vs Capybara** is a *comparison*. The reader is deciding whether to
  migrate. The page leads with the operational story (Capybara is great →
  modern async pages are flaky → `with_playwright_page` is the awkward
  escape hatch → Smartest replaces it cleanly → coexistence allows gradual
  migration), then DSL side-by-side, then fit criteria.

When editing one of these two, **read the other in the same change** and
verify:

1. The two pages do not say the same thing twice. The Rails how-to should
   not become a comparison; the comparison should not become a how-to.
2. Code examples that appear on both pages stay consistent (e.g. the
   `suspended_user_page` fixture pattern).
3. If a fact is updated (a generated file name, a default behavior, a
   method name), the change is reflected on both pages.

Prefer cross-links over duplication. The comparison page may link into
specific sections of the Rails how-to; the how-to may link to the
comparison when positioning Smartest against Capybara.

## Verifying changes

Before sending a docs PR:

```bash
cd documentation
npm run build
```

The build fails on broken internal links (`onBrokenLinks: 'throw'`), so a
clean build is a necessary baseline.

For changes that affect navigation (sidebar structure, page titles,
`sidebar_label`), also run `npm run serve` and check at minimum:

- the renamed page's `<title>` tag in the browser
- the sidebar label of the renamed page
- the breadcrumb of the renamed page
- the prev / next pager labels at the bottom of the renamed page
