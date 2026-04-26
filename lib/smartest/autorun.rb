# frozen_string_literal: true

require "English"
require_relative "../smartest"

Kernel.prepend Smartest::DSL

Smartest.register_autorun!
