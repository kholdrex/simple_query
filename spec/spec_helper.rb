# frozen_string_literal: true

require "simple_query"
require "support/database"
require "support/models/company"
require "support/models/project"
require "support/models/team"
require "support/models/user"
require "support/read_models/my_user_read_model"
require "support/read_models/test_read_model"

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Migration.verbose = false
  end

  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  config.before(:all) do
    [User, Company, Project, Team].each(&:delete_all)
  end
end
