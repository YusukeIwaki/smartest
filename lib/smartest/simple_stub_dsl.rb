# frozen_string_literal: true

module Smartest
  module SimpleStubDSL
    private

    def simple_stub_any_instance_of(klass, method_name, &block)
      apply_simple_stub(SimpleStub.new(klass, method_name, &block))
    end

    def simple_stub(object, method_name, &block)
      apply_simple_stub(SimpleStub.new(object.singleton_class, method_name, &block))
    end

    def apply_simple_stub(stub)
      stub.apply
      register_simple_stub(stub)
      stub
    end

    def register_simple_stub(_stub)
      raise NotImplementedError, "#{self.class} must implement #register_simple_stub"
    end
  end

  class SimpleStubTeardownScope
    def initialize
      @registered_stubs = []
    end

    def register(stub)
      @registered_stubs << stub
      stub
    end

    def reset_registered_stubs
      errors = []
      stubs = @registered_stubs
      @registered_stubs = []

      stubs.reverse_each do |stub|
        stub.reset
      rescue Exception => error
        raise if Smartest.fatal_exception?(error)

        errors << error
      end

      errors
    end
  end
end
