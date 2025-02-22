# SimpleQuery

SimpleQuery is a lightweight and efficient query builder for ActiveRecord, designed to provide a flexible and performant way to construct complex database queries in Ruby on Rails applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simple_query'
```

And then execute:
```bash
bundle install
```

Or install it yourself as:
```bash
gem install simple_query
```

## Configuration

By default, `SimpleQuery` does **not** automatically patch `ActiveRecord::Base`. You can **manually** include the module in individual models or in a global initializer:

```ruby
# Manual include (per model)
class User < ActiveRecord::Base
  include SimpleQuery
end

# or do it globally
ActiveRecord::Base.include(SimpleQuery)
```
If you prefer a “just works” approach (i.e., every model has `.simple_query`), you can opt in:

```ruby
# config/initializers/simple_query.rb
SimpleQuery.configure do |config|
  config.auto_include_ar = true
end
```

This tells SimpleQuery to automatically do `ActiveRecord::Base.include(SimpleQuery)` for you.

## Usage

SimpleQuery offers an intuitive interface for building queries with joins, conditions, and aggregations. Here are some examples:

Basic query
```ruby
User.simple_query.select(:name, :email).where(active: true).execute
```

Query with join
```ruby
User.simple_query
    .select(:name, :email)
    .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .where(Company.arel_table[:name].eq("TechCorp"))
    .execute
```

Complex query with multiple joins and conditions
```ruby
User.simple_query
    .select(:name)
    .join(:users, :companies, foreign_key: :user_id, primary_key: :id)
    .join(:companies, :projects, foreign_key: :company_id, primary_key: :id)
    .where(Company.arel_table[:industry].eq("Technology"))
    .where(Project.arel_table[:status].eq("active"))
    .where(User.arel_table[:admin].eq(true))
    .execute
```

Lazy execution
```ruby
User.simple_query
    .select(:name)
    .where(active: true)
    .lazy_execute
```

## Custom Read Models
By default, SimpleQuery returns results as `Struct` objects for maximum speed. However, you can also define a lightweight model class for more explicit attribute handling or custom logic.

**Create a read model** inheriting from `SimpleQuery::ReadModel`:
```ruby
class MyUserReadModel < SimpleQuery::ReadModel
  attribute :identifier, column: :id
  attribute :full_name,  column: :name
end
```

**Map query results** to your read model:
```ruby
results = User.simple_query
              .select("users.id AS id", "users.name AS name")
              .where(active: true)
              .map_to(MyUserReadModel)
              .execute

results.each do |user|
  puts user.identifier    # => user.id from the DB
  puts user.full_name     # => user.name from the DB
end
```
This custom read model approach provides more clarity or domain-specific logic while still being faster than typical ActiveRecord instantiation.

## Features

- Efficient query building
- Support for complex joins
- Lazy execution
- DISTINCT queries
- Aggregations
- LIMIT and OFFSET
- ORDER BY clause
- Having and Grouping
- Subqueries
- Custom Read models

## Performance

SimpleQuery is designed to potentially outperform standard ActiveRecord queries on large datasets. In our benchmarks with 100,000 records, SimpleQuery showed improved performance compared to equivalent ActiveRecord queries.

```
🚀 Performance Results (100,000 records):
ActiveRecord Query:                  0.47441 seconds
SimpleQuery Execution (Struct):      0.05346 seconds
SimpleQuery Execution (Read model):  0.14408 seconds
```
- The **Struct-based** approach is the fastest. 
- The **Read model** approach is still significantly faster than ActiveRecord, while letting you define custom logic or domain-specific attributes.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kholdrex/simple_query. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kholdrex/simple_query/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SimpleQuery project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/kholdrex/simple_query/blob/master/CODE_OF_CONDUCT.md).
