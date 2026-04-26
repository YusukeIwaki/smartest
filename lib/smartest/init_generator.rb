# frozen_string_literal: true

require "fileutils"

module Smartest
  class InitGenerator
    FILES = {
      "test/test_helper.rb" => <<~RUBY,
        # frozen_string_literal: true

        require "smartest/autorun"
      RUBY
      "test/example_test.rb" => <<~RUBY
        # frozen_string_literal: true

        require_relative "test_helper"

        test("example") do
          expect(1 + 1).to eq(2)
        end
      RUBY
    }.freeze

    def initialize(root: Dir.pwd, output: $stdout)
      @root = root
      @output = output
    end

    def run
      create_directory("test")
      FILES.each { |path, contents| create_file(path, contents) }

      @output.puts
      @output.puts "Run your test suite with: bundle exec smartest"

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
