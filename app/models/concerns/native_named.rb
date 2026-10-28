# English `name` is the default. `native_name` is the Lok Sabha language.
# Saving an English name fills native_name when that field is still empty.
module NativeNamed
  extend ActiveSupport::Concern

  included do
    before_validation :fill_native_name
  end

  def display_name
    return native_name if I18n.locale != I18n.default_locale && native_name.present?

    self[:name]
  end

  private

  def fill_native_name
    locale = resolved_native_locale.to_s
    return if locale.blank? || name.blank?
    return if native_name.present? && !name_changed?
    return if native_name_changed? && native_name.present?

    self.native_name = NativeScript.transliterate(name, locale)
  end
end
