# frozen_string_literal: true

require "set"

module Smartest
  class CLIArguments
    DEFAULT_PROFILE_COUNT = 5
    DEFAULT_PATHS = ["smartest/**/*_test.rb"].freeze

    attr_reader :files, :line_filters, :profile_count

    def initialize(argv)
      @files = []
      @whole_files = Set.new
      @line_filters = Hash.new { |hash, key| hash[key] = Set.new }
      @profile_count = DEFAULT_PROFILE_COUNT
      @default_paths = false

      paths = extract_options(argv)
      if paths.empty?
        @default_paths = true
        paths = DEFAULT_PATHS
      end

      parse_paths(paths)
    end

    def filter_tests?
      @line_filters.any?
    end

    def default_paths?
      @default_paths
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
          if argv[index + 1]&.match?(/\A\d+\z/)
            @profile_count = argv[index + 1].to_i
            index += 2
          else
            paths << argument
            index += 1
          end
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
        files = expand_path_pattern(pattern)

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

    def expand_path_pattern(pattern)
      matches = Dir[pattern]
      return [pattern] if matches.empty?

      matches.flat_map do |match|
        if File.directory?(match)
          Dir[File.join(match, "**", "*_test.rb")]
        else
          match
        end
      end
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
