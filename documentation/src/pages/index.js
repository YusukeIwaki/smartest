import React from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import CodeBlock from '@theme/CodeBlock';

export default function Home() {
  return (
    <Layout
      title="Smartest Documentation"
      description="Documentation for the Smartest Ruby test runner">
      <header className="hero hero--smartest">
        <div className="container text--center">
          <h1 className="hero__title">Smartest Documentation</h1>
          <p className="hero__subtitle">
            A compact Ruby test runner built around explicit keyword fixtures.
          </p>
          <div className="margin-top--md">
            <Link className="button button--primary button--lg" to="/docs/getting-started">
              Get Started
            </Link>
          </div>
          <div className="smartest-code-window">
            <div className="smartest-code-window__bar" aria-hidden="true">
              <span className="smartest-code-window__dot" />
              <span className="smartest-code-window__dot" />
              <span className="smartest-code-window__dot" />
              <span>test/example_test.rb</span>
            </div>
            <CodeBlock language="ruby">{`require "smartest/autorun"

test("factorial") do
  expect(1 * 2 * 3).to eq(6)
end`}</CodeBlock>
          </div>
        </div>
      </header>

      <main className="container margin-vert--lg">
        <div className="smartest-home-grid">
          <section className="smartest-panel">
            <h2>Write Tests</h2>
            <p>
              Define readable top-level tests and use expectation-style assertions.
            </p>
            <Link to="/docs/writing-tests">Read the guide</Link>
          </section>
          <section className="smartest-panel">
            <h2>Run Suites</h2>
            <p>
              Run a single file with autorun or execute a suite through the CLI.
            </p>
            <Link to="/docs/running-test-suites">Run tests</Link>
          </section>
          <section className="smartest-panel">
            <h2>Use Fixtures</h2>
            <p>
              Request dependencies with required Ruby keyword arguments.
            </p>
            <Link to="/docs/fixtures">Learn fixtures</Link>
          </section>
        </div>
      </main>
    </Layout>
  );
}
