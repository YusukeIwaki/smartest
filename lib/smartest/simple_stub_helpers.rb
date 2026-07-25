# frozen_string_literal: true

module Smartest
  module SimpleStubHelpers
    private

    def simple_stub_any_instance_of(klass, method_name, &block)
      apply_simple_stub(SimpleStub.new(klass, method_name, &block))
    end

    def simple_stub(object, method_name, &block)
      apply_simple_stub(SimpleStub.new(object.singleton_class, method_name, &block))
    end

    def apply_simple_stub(stub)
      stub.apply
      register_simple_stub_teardown { stub.reset }
      stub
    end
  end

  module HookScopedSimpleStubHelpers
    include SimpleStubHelpers

    private

    def initialize_simple_stub_teardowns
      @simple_stub_teardowns = []
    end

    def register_simple_stub_teardown(&block)
      @simple_stub_teardowns << block
    end

    def run_simple_stub_teardowns
      errors = []

      @simple_stub_teardowns.reverse_each do |teardown|
        teardown.call
      rescue Exception => error
        raise if Smartest.fatal_exception?(error)

        errors << error
      end

      @simple_stub_teardowns.clear
      raise errors.first if errors.any?
    end
  end
end
