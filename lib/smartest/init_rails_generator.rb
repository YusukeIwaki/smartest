# frozen_string_literal: true

require "fileutils"

module Smartest
  class InitRailsGenerator
    RAILS_SYSTEM_FIXTURE = <<~RUBY
      # frozen_string_literal: true

      require 'smartest/rails'
      require "playwright"

      class RailsSystemFixture < Smartest::Fixture
        suite_fixture :rails_server do
          # Set the environment before loading config/environment so the test
          # server cannot boot against the development database by default.
          ENV["RAILS_ENV"] ||= "test"
          ENV["RACK_ENV"] ||= ENV["RAILS_ENV"]
          require_relative "../../config/environment"

          server = Smartest::Rails::TestServer.new(app: Rails.application)
          server.start
          server.wait_for_ready

          on_teardown do
            server.stop
            server.wait_for_stopped
          end

          server
        end

        suite_fixture :base_url do |rails_server:|
          rails_server.base_url
        end

        suite_fixture :playwright do
          runtime = Playwright.create(
            playwright_cli_executable_path: "./node_modules/.bin/playwright",
          )
          on_teardown { runtime.stop }
          runtime.playwright
        end

        suite_fixture :browser do |playwright:|
          browser_type = case ENV["BROWSER"]
          when "firefox"
            :firefox
          when "webkit"
            :webkit
          else
            :chromium
          end

          launch_options = {}
          launch_options[:headless] = !%w[0 false].include?(ENV["HEADLESS"])
          if (slow_mo = ENV["SLOW_MO"].to_i) > 0
            launch_options[:slowMo] = slow_mo
          end

          browser = playwright.send(browser_type).launch(**launch_options)
          on_teardown { browser.close }
          browser
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
      missing_lines << "  use_fixture RailsSystemFixture\n" unless contents.include?("use_fixture RailsSystemFixture")
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

      if contents.match?(/gem ["']playwright-ruby-client["']/)
        @output.puts "exist   Gemfile playwright-ruby-client"
        return
      end

      separator = contents.end_with?("\n") ? "" : "\n"
      updated = "#{contents}#{separator}\ngem \"playwright-ruby-client\", group: :test\n"
      File.write(path, updated)
      @output.puts(exists ? "update  Gemfile" : "create  Gemfile")
    end

    def install_dependencies
      install_commands.each do |command|
        @output.puts "run     #{command.join(" ")}"
        next if @command_runner.call(command, chdir: @root)

        raise "command failed: #{command.join(" ")}"
      end
    end

    def install_commands
      commands = [["bundle", "install"]]
      commands << ["npm", "init", "--yes"] unless File.exist?(File.join(@root, "package.json"))
      commands << ["npm", "install", "playwright", "--save-dev"]
      commands << ["./node_modules/.bin/playwright", "install"]
      commands
    end

    def run_system_command(command, chdir:)
      system(*command, chdir: chdir)
    end
  end
end
