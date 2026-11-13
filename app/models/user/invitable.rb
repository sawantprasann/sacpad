module User::Invitable
  extend ActiveSupport::Concern

  INVITATION_TTL = 7.days

  included do
    attr_accessor :raw_invitation_token

    after_commit :send_pending_invitation, on: %i[create update]
  end

  class_methods do
    def find_by_invitation_token(raw)
      return if raw.blank?

      digest = Devise.token_generator.digest(self, :invitation_token, raw.to_s)
      find_by(invitation_token: digest)
    end
  end

  def pending_invitation?
    invitation_token.present? && invitation_accepted_at.nil?
  end

  def invitation_expired?
    invitation_sent_at.blank? || invitation_sent_at < INVITATION_TTL.ago
  end

  # Replace any posted password with a random one and email a single-use link.
  # The person cannot sign in until they accept that link.
  def deliver_invitation!
    prepare_invitation
    save
  end

  def resend_invitation!
    return false unless pending_invitation?

    prepare_invitation
    save!
  end

  def accept_invitation!(password, confirmation)
    if !pending_invitation? || invitation_expired?
      errors.add(:base, I18n.t("invite.invalid"))
      return false
    end

    self.password = password
    self.password_confirmation = confirmation
    self.invitation_token = nil
    self.invitation_accepted_at = Time.current
    self.raw_invitation_token = nil
    save
  end

  private

  def prepare_invitation
    raw, enc = Devise.token_generator.generate(self.class, :invitation_token)
    self.raw_invitation_token = raw
    self.invitation_token = enc
    self.invitation_sent_at = Time.current
    self.invitation_accepted_at = nil
    self.password = Devise.friendly_token
    self.password_confirmation = password
  end

  def send_pending_invitation
    return if raw_invitation_token.blank? || !pending_invitation?

    token = raw_invitation_token
    self.raw_invitation_token = nil
    UserMailer.invite(self, token).deliver_later
  end
end
