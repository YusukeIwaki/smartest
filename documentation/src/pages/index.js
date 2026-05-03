import React from 'react';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import CodeBlock from '@theme/CodeBlock';

export default function Home() {
  return (
    <Layout
      description="Smartest is a Ruby test runner with pytest-style fixture injection, explicit fixture dependencies, and cleanup.">
      <Head>
        <title>Smartest: Pytest-style fixtures for Ruby</title>
      </Head>
      <header className="hero hero--smartest">
        <div className="container text--center">
          <h1 className="hero__title">Smartest</h1>
          <p className="hero__subtitle">
            Pytest-style fixtures for Ruby.
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
              <span>smartest/web_test.rb</span>
            </div>
            <CodeBlock language="ruby">{`# smartest/fixtures/web_fixture.rb
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    cleanup { server.stop }
    server
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end

# smartest/test_helper.rb
around_suite do |suite|
  use_fixture WebFixture
  suite.run
end

# smartest/web_test.rb
test("GET /health") do |client:|
  response = client.get("/health")
  expect(response.status).to eq(200)
end`}</CodeBlock>
          </div>
        </div>
      </header>

      <main className="container margin-vert--lg">
        <div className="smartest-home-grid">
          <section className="smartest-panel">
            <h2>Write Tests</h2>
            <p>
              Declare test dependencies with Ruby keyword arguments.
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
              Define fixture dependencies and cleanup close to resource setup.
            </p>
            <Link to="/docs/fixtures">Learn fixtures</Link>
          </section>
        </div>
      </main>
    </Layout>
  );
}
