# frozen_string_literal: true

require "set"

module Smartest
  class CLIArguments
    DEFAULT_PROFILE_COUNT = 5

    attr_reader :files, :line_filters, :profile_count

    def initialize(argv)
      @files = []
      @whole_files = Set.new
      @line_filters = Hash.new { |hash, key| hash[key] = Set.new }
      @profile_count = nil

      paths = extract_options(argv)
      parse_paths(paths.empty? ? ["smartest/**/*_test.rb"] : paths)
    end

    def filter_tests?
      @line_filters.any?
    end

    def select_tests(tests)
      return tests unless filter_tests?

      tests.select do |test_case|
        next false unless test_case.location

        path = File.expand_path(test_case.location.path)
        @whole_files.include?(path) ||
          @line_filters.fetch(path, []).any? { |line_filter| test_case.includes_line_range?(line_filter) }
      end
    end

    private

    def extract_options(argv)
      paths = []
      index = 0

      while index < argv.length
        argument = argv[index]

        case argument
        when "--profile"
          next_argument = argv[index + 1]
          if next_argument && next_argument.match?(/\A\d+\z/)
            @profile_count = next_argument.to_i
            index += 2
          else
            @profile_count = DEFAULT_PROFILE_COUNT
            index += 1
          end
        when /\A--profile=(\d+)\z/
          @profile_count = Regexp.last_match(1).to_i
          index += 1
        else
          paths << argument
          index += 1
        end
      end

      paths
    end

    def parse_paths(paths)
      paths.each do |argument|
        pattern, line_filter = split_line_filter(argument)
        matches = Dir[pattern]
        files = matches.empty? ? [pattern] : matches

        files.each do |file|
          @files << file

          path = File.expand_path(file)
          if line_filter
            @line_filters[path].add(line_filter)
          else
            @whole_files.add(path)
          end
        end
      end

      @files.uniq!
    end

    def split_line_filter(argument)
      match = argument.match(/\A(.+):(\d+)(?:-(\d+))?\z/)
      return [argument, nil] unless match

      start_line = match[2].to_i
      end_line = match[3] ? match[3].to_i : start_line

      [match[1], start_line..end_line]
    end
  end
end
