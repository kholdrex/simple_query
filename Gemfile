# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :test do
  gem "mysql2", "~> 0.5.2"
  gem "pg", "~> 1.5.0", ">= 1.5.6"

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
    gem "memory_profiler", "~> 1.1"
    gem "sqlite3", "~> 2.1"
  else
    gem "memory_profiler", "~> 1.0.2"
    gem "sqlite3", "~> 1.5"
  end
end

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
end
