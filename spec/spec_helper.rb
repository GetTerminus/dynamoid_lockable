# frozen_string_literal: true

require 'bundler/setup'
require 'deep_cover/builtin_takeover'
require 'dynamoid_lockable'
require 'simplecov'

SimpleCov.start do
  add_filter '/vendor/'
  add_filter '/spec/'

  if ENV['CI']
    require 'simplecov-lcov'

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      c.single_report_path = 'coverage/lcov.info'
    end

    formatter SimpleCov::Formatter::LcovFormatter
  end
end

RSpec.configure do |config|
  Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require f }
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
