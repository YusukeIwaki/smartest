# Smartest Documentation Site

This directory contains the Docusaurus documentation site for Smartest.

## Development

Install dependencies:

```bash
npm install
```

Start the local development server:

```bash
npm run start
```

The default `baseUrl` is `/`, which is correct for Vercel root deployments.
The production site is:

```text
https://smartest-rb.vercel.app/
```

Set `SITE_URL=https://smartest-rb.vercel.app` in Vercel if you want to pin
canonical URLs and sitemaps to the production domain.

Build the static site:

```bash
npm run build
```

## Vercel Deployment

The repository includes a root `vercel.json` that builds this Docusaurus site
from `documentation/` and serves `documentation/build`.

Vercel settings can use either:

- project root: repository root, using `vercel.json`
- root directory: `documentation`, using the package scripts directly

Deploy the site at the domain root. The Docusaurus config uses `baseUrl: "/"`.

## Documentation Maintenance

When Smartest behavior changes, update the matching page under `docs/` in the same pull request. See `../AGENTS.md` for the rule used by AI coding agents.
