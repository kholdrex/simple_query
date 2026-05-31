# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :benchmark do
  desc "Run the optional reproducible SimpleQuery benchmark harness"
  task :reproducible do
    lib_path = File.expand_path("lib", __dir__)
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    require_relative "benchmark/simple_query_benchmark"
    SimpleQueryBenchmark.run
  end
end

task default: [:spec, :rubocop]
