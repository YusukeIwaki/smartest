# frozen_string_literal: true

require "fileutils"

module Smartest
  class InitGenerator
    FILES = {
      "smartest/test_helper.rb" => <<~RUBY,
        # frozen_string_literal: true

        require "smartest/autorun"

        Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
          require fixture_file
        end

        Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each do |matcher_file|
          require matcher_file
        end

        around_suite do |suite|
          use_matcher PredicateMatcher
          suite.run
        end
      RUBY
      "smartest/matchers/predicate_matcher.rb" => <<~RUBY,
        # frozen_string_literal: true

        module PredicateMatcher
          def method_missing(name, *arguments, &block)
            matcher_name = name.to_s
            return super unless matcher_name.match?(/\\Abe_.+\\z/)

            Matcher.new(matcher_name.delete_prefix("be_"), arguments, block)
          end

          def respond_to_missing?(name, include_private = false)
            name.to_s.match?(/\\Abe_.+\\z/) || super
          end

          class Matcher < Smartest::Matcher
            def initialize(predicate_name, arguments, block)
              @predicate_name = predicate_name
              @predicate = "\#{predicate_name}?"
              @arguments = arguments
              @block = block
            end

            def matches?(actual)
              @actual = actual
              return false unless actual.respond_to?(@predicate)

              !!actual.public_send(@predicate, *@arguments, &@block)
            end

            def failure_message
              return "expected \#{@actual.inspect} to respond to \#{@predicate}" unless @actual.respond_to?(@predicate)

              "expected \#{@actual.inspect} to be \#{description}"
            end

            def negated_failure_message
              "expected \#{@actual.inspect} not to be \#{description}"
            end

            def description
              return @predicate_name if @arguments.empty?

              "\#{@predicate_name} \#{argument_description}"
            end

            private

            def argument_description
              @arguments.map(&:inspect).join(", ")
            end
          end
        end
      RUBY
      "smartest/example_test.rb" => <<~RUBY
        # frozen_string_literal: true

        require "test_helper"

        test("example") do
          expect(1 + 1).to eq(2)
        end
      RUBY
    }.freeze

    def initialize(root: Dir.pwd, output: $stdout, files: FILES, final_message: "Run your test suite with: bundle exec smartest")
      @root = root
      @output = output
      @files = files
      @final_message = final_message
    end

    def run
      create_directory("smartest")
      create_directory("smartest/fixtures")
      create_directory("smartest/matchers")
      @files.each { |path, contents| create_file(path, contents) }

      if @final_message
        @output.puts
        @output.puts @final_message
      end

      0
    end

    private

    def create_directory(path)
      absolute_path = File.join(@root, path)

      if Dir.exist?(absolute_path)
        @output.puts "exist   #{path}"
        return
      end

      FileUtils.mkdir_p(absolute_path)
      @output.puts "create  #{path}"
    end

    def create_file(path, contents)
      absolute_path = File.join(@root, path)

      if File.exist?(absolute_path)
        @output.puts "exist   #{path}"
        return
      end

      File.write(absolute_path, contents)
      @output.puts "create  #{path}"
    end
  end
end
