# frozen_string_literal: true

require "smartest"
require "playwright"
require "playwright/test"

require_relative "playwright/init_generator"

module Smartest
  module Playwright
    VERSION = Smartest::VERSION
  end
end

module PlaywrightMatcher
  include ::Playwright::Test::Matchers
end
