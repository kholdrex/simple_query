# frozen_string_literal: true

class Company < ActiveRecord::Base
  include SimpleQuery

  belongs_to :user
  has_many :projects

  validates :name, presence: true, uniqueness: true
  validates :registration_number, presence: true, uniqueness: true

  before_create :generate_slug
  after_save :update_search_index

  scope :active, -> { where(active: true) }
  scope :by_industry, ->(industry) { where(industry: industry) }
  scope :founded_after, ->(year) { where("founded_year > ?", year) }

  simple_scope :active, -> { where(active: true) }
  simple_scope :founded_after, ->(year) { where(["founded_year > ?", year]) }

  attr_accessor :temp_registration_code

  def age
    Date.current.year - founded_year
  end

  def add_partner(partner)
    partners << partner unless partners.include?(partner)
  end

  def active_projects
    projects.where(status: "active")
  end

  def revenue_per_employee
    return 0 if total_employees.zero?

    annual_revenue / total_employees
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end

  def update_search_index
    # Logic to update search index
  end
end
