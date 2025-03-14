# frozen_string_literal: true

adapter   = ENV.fetch("DB_ADAPTER", "sqlite3")
host      = ENV["DB_HOST"]
username  = ENV["DB_USER"]
password  = ENV["DB_PASSWORD"]
database  = ENV.fetch("DB_DATABASE", ":memory:")

ActiveRecord::Base.establish_connection(
  adapter:   adapter,
  host:      host,
  username:  username,
  password:  password,
  database:  database
)

ActiveRecord::Schema.define do
  create_table :users, if_not_exists: true do |t|
    t.string  :name
    t.string  :email
    t.string  :first_name
    t.string  :last_name
    t.date    :date_of_birth
    t.boolean :active
    t.boolean :admin
    t.integer :status
  end

  create_table :companies, if_not_exists: true do |t|
    t.string  :name
    t.integer :user_id
    t.string  :registration_number
    t.integer :founded_year
    t.string  :industry
    t.boolean :active
    t.integer :size
    t.integer :status
    t.decimal :annual_revenue
    t.string  :slug
  end

  create_table :projects, if_not_exists: true do |t|
    t.string  :name
    t.integer :company_id
    t.string  :status
  end

  create_table :teams, if_not_exists: true do |t|
    t.string :name
  end

  create_table :teams_users, id: false, if_not_exists: true do |t|
    t.belongs_to :user
    t.belongs_to :team
  end
end
