class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s
    unless available_locale?(locale)
      redirect_back fallback_location: locale_fallback_path, alert: t("locale.invalid")
      return
    end

    # The app server can keep a column list from before this column existed.
    # Reload it, then write the value directly so an unchanged in-memory
    # record cannot skip the update and leave the account in English.
    if user_signed_in?
      User.reset_column_information
      User.find(current_user.id).update_columns(preferred_locale: locale, updated_at: Time.current)
    end

    cookies.permanent[:locale] = { value: locale, httponly: true, same_site: :lax }
    I18n.locale = locale
    redirect_back fallback_location: locale_fallback_path, notice: t("locale.changed"), status: :see_other
  end

  private

  def available_locale?(locale)
    choices = user_signed_in? ? allowed_locales : I18n.available_locales
    choices.map(&:to_s).include?(locale)
  end

  def locale_fallback_path
    user_signed_in? ? root_path : new_user_session_path
  end
end
