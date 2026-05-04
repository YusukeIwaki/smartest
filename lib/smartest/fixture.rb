# frozen_string_literal: true

module Smartest
  class Fixture
    RESERVED_CONTEXT_METHODS = %i[skip pending].freeze

    class << self
      def fixture(name, scope: :test, &block)
        define_fixture(
          name,
          scope: scope,
          block: block,
          location: caller_locations(1, 1).first
        )
      end

      def suite_fixture(name, &block)
        define_fixture(
          name,
          scope: :suite,
          block: block,
          location: caller_locations(1, 1).first
        )
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

      def define_fixture(name, scope:, block:, location:)
        definition = FixtureDefinition.new(
          name: name,
          block: block,
          location: location,
          scope: scope
        )

        own_fixture_definitions[definition.name] = definition
      end

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

    def simple_stub_any_instance_of(klass, method_name, &block)
      apply_simple_stub(SimpleStub.new(klass, method_name, &block))
    end

    def simple_stub(object, method_name, &block)
      apply_simple_stub(SimpleStub.new(object.singleton_class, method_name, &block))
    end

    def simple_stub_const(constant_path, value)
      owner, constant_name = resolve_simple_stub_constant(constant_path)
      original_defined = owner.const_defined?(constant_name, false)
      original_value = owner.const_get(constant_name, false) if original_defined

      owner.__send__(:remove_const, constant_name) if original_defined
      owner.const_set(constant_name, value)

      cleanup do
        owner.__send__(:remove_const, constant_name) if owner.const_defined?(constant_name, false)
        owner.const_set(constant_name, original_value) if original_defined
      end

      value
    end

    def apply_simple_stub(stub)
      stub.apply!
      cleanup { stub.reset }
      stub
    end

    def resolve_simple_stub_constant(constant_path)
      unless constant_path.is_a?(String) || constant_path.is_a?(Symbol)
        raise ArgumentError, "constant path must be a String or Symbol"
      end

      names = constant_path.to_s.split("::")
      names.shift if names.first == ""
      raise ArgumentError, "constant path must not be empty" if names.empty?

      names.each do |name|
        raise ArgumentError, "invalid constant path: #{constant_path}" unless name.match?(/\A[A-Z]\w*\z/)
      end

      constant_name = names.pop.to_sym
      owner = names.reduce(Object) { |namespace, name| namespace.const_get(name, false) }
      raise ArgumentError, "constant owner must be a Module or Class" unless owner.is_a?(Module)

      [owner, constant_name]
    end

    def method_missing(method_name, *args, &block)
      return super if RESERVED_CONTEXT_METHODS.include?(method_name)

      if @context.respond_to?(method_name, true)
        @context.__send__(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      return super if RESERVED_CONTEXT_METHODS.include?(method_name)

      @context.respond_to?(method_name, true) || super
    end
  end
end
