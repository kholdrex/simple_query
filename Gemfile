# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :test do
  gem "benchmark"
  gem "memory_profiler", "~> 1.1"
  gem "mysql2", "~> 0.5.2"
  gem "pg", "~> 1.5.0", ">= 1.5.6"
  gem "sqlite3", "~> 2.9", ">= 2.9.5"
end

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
end
