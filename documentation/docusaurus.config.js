// @ts-check

const {themes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Smartest',
  tagline: 'A small Ruby test runner with keyword-first fixtures',
  favicon: 'img/smartest-mark.svg',

  url: 'https://yusukeiwaki.github.io',
  baseUrl: '/smartest/',

  organizationName: 'YusukeIwaki',
  projectName: 'smartest',

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          routeBasePath: 'docs',
          editUrl:
            'https://github.com/YusukeIwaki/smartest/tree/main/documentation/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/smartest-mark.svg',
      navbar: {
        title: 'Smartest',
        logo: {
          alt: 'Smartest',
          src: 'img/smartest-mark.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docs',
            position: 'left',
            label: 'Docs',
          },
          {
            href: 'https://github.com/YusukeIwaki/smartest',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'light',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Getting Started',
                to: '/docs/getting-started',
              },
              {
                label: 'Writing Tests',
                to: '/docs/writing-tests',
              },
              {
                label: 'Fixtures',
                to: '/docs/fixtures',
              },
            ],
          },
          {
            title: 'Project',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/YusukeIwaki/smartest',
              },
              {
                label: 'AI Agent Rules',
                to: '/docs/contributing/ai-agent-rules',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Smartest contributors.`,
      },
      prism: {
        theme: themes.github,
        darkTheme: themes.dracula,
        additionalLanguages: ['ruby', 'bash'],
      },
    }),
};

module.exports = config;
