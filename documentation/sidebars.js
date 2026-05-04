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
    'stubs',
    'matchers',
    'helpers',
    'playwright-browser-tests',
    {
      type: 'category',
      label: 'Comparisons',
      link: {
        type: 'generated-index',
        title: 'Comparisons',
        description:
          'Compare Smartest with pytest-style fixtures, RSpec, and Minitest.',
      },
      items: [
        'pytest-style-fixtures-for-ruby',
        'smartest-vs-rspec',
        'smartest-vs-minitest',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: ['reference/errors'],
    },
  ],
};

module.exports = sidebars;
