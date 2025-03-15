# frozen_string_literal: true

require_relative "lib/simple_query/version"

Gem::Specification.new do |spec|
  spec.name          = "simple_query"
  spec.version       = SimpleQuery::VERSION
  spec.authors       = ["Alex Kholodniak"]
  spec.email         = ["alexandrkholodniak@gmail.com"]

  spec.summary       = "A lightweight and efficient query builder for ActiveRecord."
  spec.description   = "SimpleQuery provides a flexible and performant way to construct complex database queries in Ruby on Rails applications. It offers an intuitive interface for building queries with joins, conditions, and aggregations, while potentially outperforming standard ActiveRecord queries on large datasets."
  spec.homepage      = "https://github.com/kholdrex/simple_query"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/kholdrex/simple_query",
    "changelog_uri" => "https://github.com/kholdrex/simple_query/blob/master/CHANGELOG.md"
  }

  spec.files         = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0", "<= 8.0"
end
