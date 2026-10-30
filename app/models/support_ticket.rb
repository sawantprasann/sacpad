class SupportTicket < ApplicationRecord
  # Complaints about the app itself. Kitchen Cabinet tickets stay the beneficiary
  # workflow; these go to the platform team from the Support page.
  include OrganizationScoped

  CATEGORY_LABELS = {
    "general" => "General support",
    "technical" => "Technical issue",
    "account" => "Account access",
    "data" => "Data or records",
    "feature" => "Feature request"
  }.freeze

  STATUS_LABELS = {
    "pending" => "Pending",
    "in_progress" => "In progress",
    "solved" => "Solved",
    "on_hold" => "On hold"
  }.freeze

  STATUS_COLORS = {
    "pending" => "#b45309",
    "in_progress" => "#2970ff",
    "solved" => "#039855",
    "on_hold" => "#64748b"
  }.freeze

  belongs_to :user
  has_many :messages, -> { order(:created_at, :id) },
           class_name: "SupportMessage", dependent: :destroy, inverse_of: :support_ticket

  enum :category, { general: 0, technical: 1, account: 2, data: 3, feature: 4 }, default: :general, validate: true
  enum :status, { pending: 0, in_progress: 1, solved: 2, on_hold: 3 }, default: :pending, validate: true

  attr_accessor :opening_body, :images

  validates :subject, presence: true, length: { maximum: 160 }
  validate :opening_complaint_present, on: :create
  validate :opening_images_are_photos, on: :create

  before_validation :normalize_opening, on: :create
  before_create :assign_ticket_number
  after_create :record_opening_message

  def self.human_attribute_name(attr, options = {})
    return I18n.t("support.complaint") if attr.to_s == "opening_body"

    super
  end

  def self.category_options
    CATEGORY_LABELS.keys.map { |key| [ I18n.t("support.categories.#{key}", default: CATEGORY_LABELS[key]), key ] }
  end

  def self.status_options
    STATUS_LABELS.keys.map { |key| [ I18n.t("support.statuses.#{key}", default: STATUS_LABELS[key]), key ] }
  end

  def self.apply_list_filters(relation, status:, query:)
    filtered = case status.to_s
    when "solved" then relation.solved
    when "pending" then relation.where.not(status: :solved)
    else relation
    end
    filtered = search_relation(filtered, query)
    filtered.order("support_tickets.updated_at DESC")
  end

  def self.search_relation(relation, query)
    term = query.to_s.strip
    return relation if term.blank?

    like = "%#{sanitize_sql_like(term)}%"
    relation.left_joins(:user, :organization).where(<<~SQL.squish, q: like)
      support_tickets.subject ILIKE :q
      OR support_tickets.ticket_number ILIKE :q
      OR users.name ILIKE :q
      OR users.email ILIKE :q
      OR organizations.name ILIKE :q
    SQL
  end

  def self.summary_counts(relation)
    {
      total: relation.count,
      pending: relation.where.not(status: :solved).count,
      solved: relation.solved.count
    }
  end

  def category_label
    I18n.t("support.categories.#{category}", default: CATEGORY_LABELS[category])
  end

  def status_label
    I18n.t("support.statuses.#{status}", default: STATUS_LABELS[status])
  end

  def status_color
    STATUS_COLORS[status]
  end

  private

  def opening_complaint_present
    errors.add(:opening_body, "can't be blank") if opening_body.blank?
  end

  def opening_images_are_photos
    SupportMessage.image_problems(images).each { |problem| errors.add(:images, problem) }
  end

  def normalize_opening
    self.subject = subject.to_s.strip
    self.opening_body = opening_body.to_s.strip.presence
  end

  def assign_ticket_number
    return if ticket_number.present?

    seq = self.class.where(organization_id: organization_id).count + 1
    self.ticket_number = format("SP-%d-%05d", organization_id, seq)
  end

  def record_opening_message
    message = messages.create!(body: opening_body, author: user, organization: organization)
    files = Array(images).reject(&:blank?)
    message.images.attach(files) if files.any?
  end
end
