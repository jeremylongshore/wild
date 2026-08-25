# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __dir__)

# Without this, `bundle exec packwerk check` boots the dummy app under
# whatever RAILS_ENV the invoking shell happens to have set (often unset,
# which Rails treats as "development"), while `bundle exec rspec` boots it
# under "test" via rails_helper. Two different environments loading the
# same config/application.rb defeats the point of a single dummy app: pin
# it to "test" here so every entry point (rspec, packwerk, brakeman) boots
# the same configuration.
ENV["RAILS_ENV"] ||= "test"

require "bundler/setup" # Set up gems listed in the Gemfile.
