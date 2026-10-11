# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :test do
  gem "mysql2", "~> 0.5.2"
  gem "pg", "~> 1.5.0", ">= 1.5.6"

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
    gem "memory_profiler", "~> 1.1"
  else
    gem "memory_profiler", "~> 1.0.2"
  end

  # sqlite3 2.9.5+ fixes a use-after-free and needs Ruby 3.2. On older Rubies,
  # run the specs against PostgreSQL or MySQL (DB_ADAPTER=...), as CI does.
  gem "sqlite3", "~> 2.9", ">= 2.9.5" if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.2.0")
end

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
end
