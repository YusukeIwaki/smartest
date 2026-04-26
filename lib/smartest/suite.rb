# frozen_string_literal: true

module Smartest
  class Suite
    attr_reader :tests, :fixture_classes

    def initialize
      @tests = TestRegistry.new
      @fixture_classes = FixtureClassRegistry.new
    end
  end
end
