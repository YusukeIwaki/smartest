# frozen_string_literal: true

module Smartest
  module ConstantStubHelpers
    private

    def with_stub_const(constant_path, value)
      raise ArgumentError, "with_stub_const block is required" unless block_given?

      owner, constant_name = resolve_with_stub_constant(constant_path)
      original_defined = owner.const_defined?(constant_name, false)
      original_value = owner.const_get(constant_name, false) if original_defined

      owner.__send__(:remove_const, constant_name) if original_defined
      owner.const_set(constant_name, value)

      yield
    ensure
      if owner && constant_name
        owner.__send__(:remove_const, constant_name) if owner.const_defined?(constant_name, false)
        owner.const_set(constant_name, original_value) if original_defined
      end
    end

    def resolve_with_stub_constant(constant_path)
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
  end
end
