class UserMailer < ApplicationMailer
  def invite(user, raw_token)
    if Rails.env.production? && (ENV["BREVO_SMTP_LOGIN"].blank? || ENV["BREVO_SMTP_KEY"].blank?)
      raise "Set BREVO_SMTP_LOGIN and BREVO_SMTP_KEY before sending invites."
    end

    @user = user
    @url = edit_invitation_url(token: raw_token)

    I18n.with_locale(:en) do
      mail to: user.email, subject: I18n.t("invite.email_subject", organization: user.organization.name)
    end
  end
end
