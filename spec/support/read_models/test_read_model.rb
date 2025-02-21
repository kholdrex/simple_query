# frozen_string_literal: true

class TestReadModel < SimpleQuery::ReadModel
  attribute :foo
  attribute :bar, column: :baz
end
