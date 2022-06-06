# frozen_string_literal: true

ENV['AWS_REGION'] ||= 'us-east-1'
ENV['AWS_ACCESS_KEY_ID'] ||= 'foo'
ENV['AWS_SECRET_ACCESS_KEY'] ||= 'foo'

require 'dynamoid'
require 'dynamoid_advanced_where'

Dynamoid.configure do |config|
  config.logger = Logger.new('/dev/null')
  config.namespace = SecureRandom.uuid.tr('-', '')
  config.endpoint =  ENV.fetch('DYNAMODB_HOST', 'http://localhost:8000')
end
