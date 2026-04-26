---
title: Releasing
description: Build and publish the Smartest Ruby gem.
---

# Releasing

Smartest is packaged as the `smartest` Ruby gem.

## Files Used for Packaging

The gem package is defined by:

- `smartest.gemspec`
- `lib/smartest/version.rb`
- `Gemfile`
- `Rakefile`
- `CHANGELOG.md`
- `LICENSE`
- `README.md`

The executable is exposed from `exe/smartest`.

## Local Verification

Run the test suite:

```bash
rake test
```

Build the gem:

```bash
rake build
```

Install the built gem locally:

```bash
gem install ./pkg/smartest-0.1.0.gem
```

Verify the installed executable:

```bash
smartest --version
```

Then run a sample test file:

```bash
bundle exec smartest
```

## Publishing

Before publishing:

1. Update `Smartest::VERSION` in `lib/smartest/version.rb`.
2. Update `CHANGELOG.md`.
3. Run `rake verify`.
4. Install and smoke-test the built gem.
5. Make sure the GitHub repository has a `RUBYGEMS_API_KEY` secret.
6. Push a tag that matches `Smartest::VERSION`.

Release tags must use one of these formats:

- `0.1.0`
- `0.1.0.alpha1`

Example:

```bash
git tag 0.1.0
git push origin 0.1.0
```

Pushing the tag triggers the Deploy GitHub Actions workflow. The workflow checks
that `Smartest::VERSION` matches the tag, runs `rake verify`, and pushes the
built `pkg/smartest-$VERSION.gem` package to RubyGems.
