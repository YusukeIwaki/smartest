# frozen_string_literal: true

module Smartest
  module DSL
    def test(name, **metadata, &block)
      location = caller_locations(1, 1).first

      Smartest.suite.tests.add(
        TestCase.new(
          name: name,
          metadata: metadata,
          block: block,
          location: location,
          around_test_hooks: Smartest.suite.around_test_hooks_for(location)
        )
      )
    end

    def around_suite(&block)
      raise ArgumentError, "around_suite block is required" unless block

      Smartest.suite.around_suite_hooks << block
    end

    def around_test(&block)
      raise ArgumentError, "around_test block is required" unless block

      Smartest.suite.add_around_test_hook(caller_locations(1, 1).first, block)
    end

    private :test, :around_suite, :around_test
  end
end
