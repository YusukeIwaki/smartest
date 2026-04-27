# frozen_string_literal: true

module Smartest
  class Suite
    attr_reader :tests, :fixture_classes, :matcher_modules

    def initialize
      @tests = TestRegistry.new
      @fixture_classes = FixtureClassRegistry.new
      @matcher_modules = MatcherRegistry.new
    end
  end
end
