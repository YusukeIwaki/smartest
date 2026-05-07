# frozen_string_literal: true

require "digest"

module Smartest
  class SimpleStub
    class AlreadyAppliedError < Smartest::Error; end
    class NotAppliedError < Smartest::Error; end

    class LocalStore
      def initialize
        @mutex = Mutex.new
        @stubs = {}
      end

      def fetch(key, default = nil)
        @mutex.synchronize do
          stack = @stubs[key]
          stack && !stack.empty? ? stack.last.fetch(:implementation) : default
        end
      end

      def set(key, implementation)
        @mutex.synchronize do
          entry = { implementation: implementation }
          (@stubs[key] ||= []) << entry
          entry
        end
      end

      def delete(key, entry = nil)
        @mutex.synchronize do
          stack = @stubs[key]
          if stack && !stack.empty?
            removed = if entry
              index = stack.rindex { |candidate| candidate.equal?(entry) }
              index ? stack.delete_at(index) : nil
            else
              stack.pop
            end

            @stubs.delete(key) if stack.empty?
            removed&.fetch(:implementation)
          end
        end
      end

      def key?(key)
        @mutex.synchronize do
          stack = @stubs[key]
          !!(stack && !stack.empty?)
        end
      end

      def include?(key, entry)
        @mutex.synchronize do
          stack = @stubs[key]
          stack ? stack.any? { |candidate| candidate.equal?(entry) } : false
        end
      end

      def empty?
        @mutex.synchronize { @stubs.empty? }
      end

      def clear
        @mutex.synchronize { @stubs.clear }
      end
    end

    class << self
      def implementation_for(klass_key, method_name)
        key = stub_key(klass_key, method_name)
        store = current_store_if_defined
        return nil unless store&.key?(key)

        store.fetch(key)
      end

      def active_stubs
        current_store
      end

      def clear_active_stubs_if_empty
        @default_store = nil if @default_store&.empty?
      end

      def current_stubs
        store = current_store_if_defined
        store&.empty? ? nil : store
      end

      def current_store
        active_store || default_store
      end

      def with_store(store, clear: true)
        unless store.respond_to?(:fetch) && store.respond_to?(:set) && store.respond_to?(:delete)
          raise ArgumentError, "store must respond to fetch, set, and delete"
        end

        previous_store = nil
        store_mutex.synchronize do
          previous_store = @active_store
          @active_store = store
        end

        yield
      ensure
        store_mutex.synchronize { @active_store = previous_store }
        store.clear if clear && store.respond_to?(:clear)
      end

      def ensure_dispatcher_method(klass, klass_key, method_name)
        dispatcher_mutex.synchronize do
          mod = dispatcher_module_for(klass, klass_key)
          next if mod.method_defined?(method_name) || mod.private_method_defined?(method_name)

          mod.define_method(method_name) do |*args, **kwargs, &block|
            implementation = SimpleStub.implementation_for(klass_key, method_name)

            if implementation
              SimpleStub.call_implementation(self, implementation, args, kwargs, block)
            elsif kwargs.empty?
              super(*args, &block)
            else
              super(*args, **kwargs, &block)
            end
          end
        end
      end

      def stub_key(klass_key, method_name)
        [klass_key, method_name]
      end

      def call_implementation(receiver, implementation, args, kwargs, block)
        return call_implementation_with_block(receiver, implementation, args, kwargs, block) if block

        if kwargs.empty?
          receiver.instance_exec(*args, &implementation)
        else
          receiver.instance_exec(*args, **kwargs, &implementation)
        end
      end

      def call_implementation_with_block(receiver, implementation, args, kwargs, block)
        method_name = next_call_method_name
        singleton_class = receiver.singleton_class
        singleton_class.__send__(:define_method, method_name, &implementation)

        if kwargs.empty?
          receiver.__send__(method_name, *args, &block)
        else
          receiver.__send__(method_name, *args, **kwargs, &block)
        end
      ensure
        if singleton_class &&
            (singleton_class.method_defined?(method_name) || singleton_class.private_method_defined?(method_name))
          singleton_class.__send__(:remove_method, method_name)
        end
      end

      private

      def current_store_if_defined
        active_store || default_store_if_defined
      end

      def active_store
        store_mutex.synchronize { @active_store }
      end

      def default_store
        store_mutex.synchronize { @default_store ||= LocalStore.new }
      end

      def default_store_if_defined
        store_mutex.synchronize { @default_store }
      end

      def store_mutex
        @store_mutex ||= Mutex.new
      end

      def dispatcher_module_for(klass, klass_key)
        const_name = dispatcher_module_name(klass_key)

        if const_defined?(const_name, false)
          const_get(const_name, false)
        else
          Module.new.tap do |mod|
            const_set(const_name, mod)
            klass.prepend(mod)
          end
        end
      end

      def dispatcher_module_name(klass_key)
        "StubDispatcher#{klass_key}"
      end

      def dispatcher_mutex
        @dispatcher_mutex ||= Mutex.new
      end

      def next_call_method_name
        call_mutex.synchronize do
          @call_sequence ||= 0
          @call_sequence += 1
          :"__smartest_simple_stub_call_#{@call_sequence}"
        end
      end

      def call_mutex
        @call_mutex ||= Mutex.new
      end
    end

    def initialize(klass, method_name, &implementation)
      raise ArgumentError, "klass must be a Class. #{klass.class} specified." unless klass.is_a?(Class)
      raise ArgumentError, "method name must be a Symbol." unless method_name.is_a?(Symbol)

      @klass = klass
      @method_name = method_name
      @implementation = implementation
    end

    def apply
      return if applied?

      apply_stub
    end

    def apply!
      raise AlreadyAppliedError, "stub for #{@klass}##{@method_name} is already applied" if applied?

      apply_stub
    end

    def reset
      return if @stub_entry && !applied?
      return unless applied? || stub_available?

      reset_stub
    end

    def reset!
      raise NotAppliedError, "stub for #{@klass}##{@method_name} is not applied" if @stub_entry && !applied?
      raise NotAppliedError, "stub for #{@klass}##{@method_name} is not applied" unless applied? || stub_available?

      reset_stub
    end

    private

    def apply_stub
      raise ArgumentError, "block must be given for applying stub" unless @implementation

      self.class.ensure_dispatcher_method(@klass, klass_key, @method_name)
      @stub_entry = active_stubs.set(stub_key, @implementation)
    end

    def reset_stub
      active_stubs.delete(stub_key, @stub_entry)
      @stub_entry = nil
      self.class.clear_active_stubs_if_empty
    end

    def active_stubs
      self.class.active_stubs
    end

    def stub_key
      self.class.stub_key(klass_key, @method_name)
    end

    def klass_key
      @klass_key ||= Digest::SHA256.hexdigest(@klass.object_id.to_s)
    end

    def applied?
      @stub_entry && self.class.current_stubs&.include?(stub_key, @stub_entry)
    end

    def stub_available?
      self.class.current_stubs&.key?(stub_key)
    end
  end
end
