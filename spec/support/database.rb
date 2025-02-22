# frozen_string_literal: true

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name
    t.string :email
    t.string :first_name
    t.string :last_name
    t.date :date_of_birth
    t.boolean :active
    t.boolean :admin
    t.integer :status
  end

  create_table :companies do |t|
    t.string :name
    t.integer :user_id
    t.string :registration_number
    t.integer :founded_year
    t.string :industry
    t.boolean :active
    t.integer :size
    t.integer :status
    t.decimal :annual_revenue
    t.string :slug
  end

  create_table :projects do |t|
    t.string :name
    t.integer :company_id
    t.string :status
  end

  create_table :teams do |t|
    t.string :name
  end

  create_table :teams_users, id: false do |t|
    t.belongs_to :user
    t.belongs_to :team
  end
end
