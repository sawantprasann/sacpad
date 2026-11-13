class DeviseMailer < Devise::Mailer
  # Invite mail is always English. Password reset uses the same template and language.
  def reset_password_instructions(record, token, opts = {})
    I18n.with_locale(:en) do
      opts[:subject] = I18n.t("password_reset.email_subject")
      super
    end
  end
end
