# frozen_string_literal: true

module Smartest
  class FixtureClassRegistry
    include Enumerable

    def initialize
      @fixture_classes = []
    end

    def add(klass)
      unless klass.is_a?(Class) && klass <= Fixture
        raise ArgumentError, "fixture class must inherit from Smartest::Fixture"
      end

      @fixture_classes << klass unless @fixture_classes.include?(klass)
    end

    def each(&block)
      @fixture_classes.each(&block)
    end

    def to_a
      @fixture_classes.dup
    end
  end
end
