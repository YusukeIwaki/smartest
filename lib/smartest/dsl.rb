# frozen_string_literal: true

module Smartest
  module DSL
    def test(name, **metadata, &block)
      Smartest.suite.tests.add(
        TestCase.new(
          name: name,
          metadata: metadata,
          block: block,
          location: caller_locations(1, 1).first
        )
      )
    end

    def use_fixture(klass)
      Smartest.suite.fixture_classes.add(klass)
    end

    def use_matcher(matcher_module)
      Smartest.suite.matcher_modules.add(matcher_module)
    end

    private :test, :use_fixture, :use_matcher
  end
end
