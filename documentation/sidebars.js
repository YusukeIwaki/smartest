// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    'getting-started',
    'writing-tests',
    'running-test-suites',
    'skipping-tests',
    'fixtures',
    'matchers',
    'playwright-browser-tests',
    {
      type: 'category',
      label: 'Reference',
      items: ['reference/errors'],
    },
  ],
};

module.exports = sidebars;
