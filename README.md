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

## Features

- Efficient query building
- Support for complex joins
- Lazy execution
- DISTINCT queries
- Aggregations
- LIMIT and OFFSET
- ORDER BY clause
- Subqueries

## Performance

SimpleQuery is designed to potentially outperform standard ActiveRecord queries on large datasets. In our benchmarks with 100,000 records, SimpleQuery showed improved performance compared to equivalent ActiveRecord queries.

```
🚀 Performance Results (100,000 records):
ActiveRecord Query:        0.43343 seconds
SimpleQuery Execution:      0.06186 seconds
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kholdrex/simple_query. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kholdrex/simple_query/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SimpleQuery project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/kholdrex/simple_query/blob/master/CODE_OF_CONDUCT.md).
