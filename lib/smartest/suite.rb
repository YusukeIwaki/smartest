# frozen_string_literal: true

module Smartest
  class Suite
    attr_reader :tests, :fixture_classes, :matcher_modules, :around_suite_hooks, :around_test_hooks

    def initialize
      @tests = TestRegistry.new
      @fixture_classes = FixtureClassRegistry.new
      @matcher_modules = MatcherRegistry.new
      @around_suite_hooks = []
      @around_test_hooks = []
      @around_test_hooks_by_file = Hash.new { |hash, path| hash[path] = [] }
      @around_suite_hook_depth = 0
    end

    def add_around_test_hook(location, hook)
      if running_around_suite_hook?
        @around_test_hooks << hook
      else
        @around_test_hooks_by_file[path_for(location)] << hook
      end
    end

    def around_test_hooks_for(location)
      @around_test_hooks_by_file[path_for(location)].dup
    end

    def around_suite_hook
      @around_suite_hook_depth += 1
      yield
    ensure
      @around_suite_hook_depth -= 1
    end

    private

    def running_around_suite_hook?
      @around_suite_hook_depth.positive?
    end

    def path_for(location)
      File.expand_path(location.absolute_path || location.path)
    end
  end
end
