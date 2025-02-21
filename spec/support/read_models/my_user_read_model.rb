# frozen_string_literal: true

class MyUserReadModel < SimpleQuery::ReadModel
  attribute :identifier, column: "id"
  attribute :full_name,  column: "name"

  def admin?
    full_name == "Admin"
  end
end
