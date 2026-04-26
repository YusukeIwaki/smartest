// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    'getting-started',
    'writing-tests',
    'running-test-suites',
    'fixtures',
    'playwright-browser-tests',
    {
      type: 'category',
      label: 'Reference',
      items: ['reference/expectations', 'reference/errors'],
    },
    {
      type: 'category',
      label: 'Contributing',
      items: ['contributing/ai-agent-rules', 'contributing/releasing'],
    },
  ],
};

module.exports = sidebars;
