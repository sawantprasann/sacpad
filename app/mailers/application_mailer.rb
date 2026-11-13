class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAIL_FROM"].presence || "Politomatrix <no-reply@politomatrix.com>"
  layout "mailer"
end
