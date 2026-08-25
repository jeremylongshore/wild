# frozen_string_literal: true

# Packwerk hardcodes `Packwerk::RailsLoadPaths.require_application` to
# `#{root_path}/config/environment.rb`, where root_path is the directory
# holding packwerk.yml (the repo root). `wild` is a Rails *engine* gem, not
# a Rails application, so the repo root has no Rails app of its own — the
# app packwerk needs to introspect autoload paths against lives at
# spec/dummy/ (see spec/dummy/config/environment.rb). This file exists only
# to satisfy that hardcoded lookup; it delegates immediately.
#
# wild.gemspec's spec.files reject list excludes "config/" (same treatment
# as packwerk.yml itself), so this dev-only shim is never packaged into the
# released gem.
require_relative "../spec/dummy/config/environment"
