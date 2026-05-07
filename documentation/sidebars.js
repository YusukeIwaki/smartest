// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    {
      type: 'category',
      label: 'Introduction',
      collapsed: false,
      items: ['intro', 'getting-started'],
    },
    {
      type: 'category',
      label: 'Learn',
      collapsed: false,
      items: [
        'writing-tests',
        'fixtures',
        'stubs',
        'matchers',
        'helpers',
        'skipping-tests',
        'running-test-suites',
      ],
    },
    {
      type: 'category',
      label: 'Browser Tests',
      collapsed: false,
      items: ['playwright-browser-tests', 'rails-browser-tests'],
    },
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
