# frozen_string_literal: true

class User < ActiveRecord::Base
  include SimpleQuery

  has_many :companies
  has_many :projects, through: :companies
  has_and_belongs_to_many :teams

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, uniqueness: true,
                    format: { with: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
  validates :age, numericality: { greater_than_or_equal_to: 18 }, allow_nil: true

  before_save :normalize_email
  after_create :send_welcome_email

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(admin: true) }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }

  attr_accessor :temp_password

  def self.search(query)
    where("name LIKE ? OR email LIKE ?", "%#{query}%", "%#{query}%")
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def age
    return nil unless date_of_birth

    ((Time.zone.now - date_of_birth.to_time) / 1.year.seconds).floor
  end

  def active_companies
    companies.where(active: true)
  end

  def total_projects
    projects.count
  end

  def assign_to_team(team)
    teams << team unless teams.include?(team)
  end

  def admin?
    admin
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email
  end

  def send_welcome_email
    # Logic to send welcome email
  end
end
