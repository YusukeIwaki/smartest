# frozen_string_literal: true

require "fileutils"

module Smartest
  class InitRailsGenerator
    RAILS_SYSTEM_FIXTURE = <<~RUBY
      # frozen_string_literal: true

      require 'smartest/rails'
      require "playwright"

      # Force the test environment and load Rails while test_helper is required
      # so app constants are available before per-test fixtures are resolved.
      ENV["RAILS_ENV"] = "test"
      ENV["RACK_ENV"] = "test"
      require_relative "../../config/environment"

      class RailsSystemTestFixture < Smartest::Fixture
        suite_fixture :rails_server do
          server = Smartest::Rails::TestServer.new(
            app: Rails.application,
            host: ENV["SMARTEST_RAILS_TEST_SERVER_HOST"],
            port: ENV["SMARTEST_RAILS_TEST_SERVER_PORT"],
          )
          server.start
          server.wait_for_ready

          on_teardown do
            server.stop
            server.wait_for_stopped
          end

          server
        end

        suite_fixture :base_url do |rails_server:|
          ENV.fetch("SMARTEST_RAILS_BASE_URL", rails_server.base_url)
        end

        suite_fixture :browser do
          ws_endpoint = ENV["PLAYWRIGHT_WS_ENDPOINT"]

          if ws_endpoint && !ws_endpoint.empty?
            playwright_execution = Playwright.connect_to_browser_server(
              ws_endpoint,
              browser_type: selected_browser_type.to_s,
            )
            on_teardown { playwright_execution.stop }

            playwright_execution.browser
          else
            playwright_execution = Playwright.create(
              playwright_cli_executable_path: ENV.fetch(
                "PLAYWRIGHT_CLI_EXECUTABLE_PATH",
                "./node_modules/.bin/playwright",
              )
            )
            on_teardown { playwright_execution.stop }

            playwright = playwright_execution.playwright
            browser = playwright.public_send(selected_browser_type).launch(**browser_launch_options)
            on_teardown { browser.close }
            browser
          end
        end

        fixture :browser_context do |base_url:, browser:|
          context = browser.new_context(baseURL: base_url)
          on_teardown { context.close }
          context
        end

        fixture :page do |browser_context:|
          page = browser_context.new_page
          on_teardown { page.close }
          page
        end

        private

        def selected_browser_type
          case ENV.fetch("BROWSER", "chromium")
          when "firefox"
            :firefox
          when "webkit"
            :webkit
          else
            :chromium
          end
        end

        def browser_launch_options
          launch_options = {}
          launch_options[:headless] = !%w[0 false].include?(ENV.fetch("HEADLESS", "true"))
          if (slow_mo = ENV.fetch("SLOW_MO", "0").to_i) > 0
            launch_options[:slowMo] = slow_mo
          end

          launch_options
        end
      end
    RUBY

    PLAYWRIGHT_MATCHER = <<~RUBY
      # frozen_string_literal: true

      require "playwright"
      require "playwright/test"

      module PlaywrightMatcher
        include Playwright::Test::Matchers
      end
    RUBY

    EXAMPLE_RAILS_SYSTEM_TEST = <<~RUBY
      # frozen_string_literal: true

      require "test_helper"

      test("loads the Rails application") do |page:|
        response = page.goto("/")

        expect(response.status).to be_between(200, 599)
      end
    RUBY

    def initialize(root: Dir.pwd, output: $stdout, command_runner: nil)
      @root = root
      @output = output
      @command_runner = command_runner || method(:run_system_command)
    end

    def run
      Smartest::InitGenerator.new(
        root: @root,
        output: @output,
        files: smartest_files,
        final_message: nil
      ).run
      create_file("smartest/fixtures/rails_system_fixture.rb", RAILS_SYSTEM_FIXTURE)
      create_file("smartest/matchers/playwright_matcher.rb", PLAYWRIGHT_MATCHER)
      update_test_helper
      update_gemfile
      install_dependencies
      @output.puts
      @output.puts "Run your Rails browser test suite with: bundle exec smartest smartest/example_rails_system_test.rb"

      0
    end

    private

    def smartest_files
      Smartest::InitGenerator::FILES.merge("smartest/example_rails_system_test.rb" => EXAMPLE_RAILS_SYSTEM_TEST)
    end

    def create_file(path, contents)
      absolute_path = File.join(@root, path)

      if File.exist?(absolute_path)
        @output.puts "exist   #{path}"
        return
      end

      FileUtils.mkdir_p(File.dirname(absolute_path))
      File.write(absolute_path, contents)
      @output.puts "create  #{path}"
    end

    def update_test_helper
      path = File.join(@root, "smartest/test_helper.rb")
      contents = File.read(path)
      updated = ensure_rails_registered(contents)

      return if updated == contents

      File.write(path, updated)
      @output.puts "update  smartest/test_helper.rb"
    end

    def ensure_rails_registered(contents)
      missing_lines = []
      missing_lines << "  use_fixture RailsSystemTestFixture\n" unless contents.include?("use_fixture RailsSystemTestFixture")
      missing_lines << "  use_matcher PlaywrightMatcher\n" unless contents.include?("use_matcher PlaywrightMatcher")
      return contents if missing_lines.empty?

      if contents.include?("use_matcher PredicateMatcher")
        contents.sub(/^(\s*use_matcher PredicateMatcher\n)/) do
          "#{Regexp.last_match(1)}#{missing_lines.join}"
        end
      else
        "#{contents.chomp}\n\naround_suite do |suite|\n#{missing_lines.join}  suite.run\nend\n"
      end
    end

    def update_gemfile
      path = File.join(@root, "Gemfile")
      exists = File.exist?(path)
      contents = exists ? File.read(path) : "source \"https://rubygems.org\"\n"
      updated = contents.dup

      unless gem_present?(updated, "smartest")
        updated = append_gem(updated, 'gem "smartest"')
      end

      if gem_present?(updated, "playwright-ruby-client")
        @output.puts "exist   Gemfile playwright-ruby-client"
      else
        updated = append_gem(updated, 'gem "playwright-ruby-client", group: :test')
      end

      if updated != contents
        File.write(path, updated)
        @output.puts(exists ? "update  Gemfile" : "create  Gemfile")
      end
    end

    def append_gem(contents, line)
      separator = contents.end_with?("\n") ? "" : "\n"
      "#{contents}#{separator}\n#{line}\n"
    end

    def gem_present?(contents, name)
      contents.each_line.any? do |line|
        line.match?(/\A\s*gem\s+["']#{Regexp.escape(name)}["']/)
      end
    end

    def install_dependencies
      commands = install_commands

      with_unbundled_env do
        commands.each do |command|
          @output.puts "run     #{command.join(" ")}"
          next if @command_runner.call(command, chdir: @root)

          raise "command failed: #{command.join(" ")}"
        end
      end

      if skip_browser_download?
        @output.puts "skip    ./node_modules/.bin/playwright install (SMARTEST_SKIP_BROWSER_DOWNLOAD=1)"
      end
    end

    def install_commands
      commands = [["bundle", "install"]]
      commands << ["npm", "init", "--yes"] unless File.exist?(File.join(@root, "package.json"))
      commands << ["npm", "install", "playwright", "--save-dev"]
      commands << ["./node_modules/.bin/playwright", "install"] unless skip_browser_download?
      commands
    end

    def skip_browser_download?
      %w[1 true].include?(ENV.fetch("SMARTEST_SKIP_BROWSER_DOWNLOAD", "false"))
    end

    def run_system_command(command, chdir:)
      system(*command, chdir: chdir)
    end

    def with_unbundled_env(&block)
      require "bundler"

      if Bundler.respond_to?(:with_unbundled_env)
        Bundler.with_unbundled_env(&block)
      else
        Bundler.with_clean_env(&block)
      end
    end
  end
end
