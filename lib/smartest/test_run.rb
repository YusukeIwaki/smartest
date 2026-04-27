# frozen_string_literal: true

module Smartest
  class TestRun
    attr_reader :result

    def initialize(fixture_classes:, matcher_modules:, helper_modules: [], &block)
      @fixture_classes = FixtureClassRegistry.new
      fixture_classes.each { |fixture_class| @fixture_classes.add(fixture_class) }

      @matcher_modules = MatcherRegistry.new
      matcher_modules.each { |matcher_module| @matcher_modules.add(matcher_module) }

      @helper_modules = HelperRegistry.new
      helper_modules.each { |helper_module| @helper_modules.add(helper_module) }

      @block = block
      @ran = false
      @result = nil
    end

    def run
      raise AroundTestRunError, "around_test hook called test.run more than once" if ran?

      @ran = true
      @result = @block.call(
        fixture_classes: @fixture_classes,
        matcher_modules: @matcher_modules,
        helper_modules: @helper_modules
      )
    end

    def ran?
      @ran
    end

    def add_fixture_class(klass)
      raise AroundTestRunError, "use_fixture must be called before test.run" if ran?

      reject_suite_fixture_class!(klass)
      @fixture_classes.add(klass)
    end

    def add_matcher_module(matcher_module)
      raise AroundTestRunError, "use_matcher must be called before test.run" if ran?

      @matcher_modules.add(matcher_module)
    end

    def add_helper_module(helper_module)
      raise AroundTestRunError, "use_helper must be called before test.run" if ran?

      @helper_modules.add(helper_module)
    end

    private

    def reject_suite_fixture_class!(klass)
      return unless klass.is_a?(Class) && klass <= Fixture

      suite_fixture_names = klass.fixture_definitions.each_value.filter_map do |definition|
        definition.name if definition.scope == :suite
      end

      raise AroundTestFixtureScopeError.new(klass, suite_fixture_names) if suite_fixture_names.any?
    end
  end
end
