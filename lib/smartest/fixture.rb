# frozen_string_literal: true

module Smartest
  class Fixture
    class << self
      def fixture(name, &block)
        definition = FixtureDefinition.new(
          name: name,
          block: block,
          location: caller_locations(1, 1).first
        )

        own_fixture_definitions[definition.name] = definition
      end

      def fixture_definitions
        inherited =
          if superclass.respond_to?(:fixture_definitions)
            superclass.fixture_definitions
          else
            {}
          end

        inherited.merge(own_fixture_definitions)
      end

      private

      def own_fixture_definitions
        @fixture_definitions ||= {}
      end
    end

    def initialize(fixture_set:, context:)
      @fixture_set = fixture_set
      @context = context
    end

    private

    def cleanup(&block)
      raise ArgumentError, "cleanup block is required" unless block

      @fixture_set.add_cleanup(&block)
    end

    def method_missing(method_name, *args, &block)
      if @context.respond_to?(method_name, true)
        @context.__send__(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @context.respond_to?(method_name, true) || super
    end
  end
end
