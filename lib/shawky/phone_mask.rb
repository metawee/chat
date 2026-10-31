# Turns phone-number-looking strings into masked placeholders.
module Shawky::PhoneMask
  MASK_CHAR = '•'.freeze
  HIDDEN = (MASK_CHAR * 8)
  PHONE_CHARS = /\A\+?[\d\s\-().]+\z/
  # A run of 8–15 digits, optionally led by '+', with common separators in between.
  EMBEDDED_PHONE = /\+?\d(?:[\s\-().]?\d){7,14}/
  # Strings made of digits and separators that are not phone numbers.
  NOT_PHONE = [/\A\d{4}-\d{2}-\d{2}\z/, /\A\d{1,3}(\.\d{1,3}){3}\z/].freeze
  MIN_DIGITS = 8
  MAX_DIGITS = 15

  module_function

  # Masking is on for the account (Settings → Shawky) and not killed installation-wide.
  def enabled?(account)
    Shawky::Config.enabled?(:phone_masking) && Shawky::Settings.enabled?(account, :phone_masking)
  end

  def phone_like?(value)
    return false unless value.is_a?(String) && value.match?(PHONE_CHARS)
    return false if NOT_PHONE.any? { |pattern| value.match?(pattern) }

    value.count('0-9').between?(MIN_DIGITS, MAX_DIGITS)
  end

  def masked?(value)
    value.is_a?(String) && value.include?(MASK_CHAR)
  end

  def mask(value, mode = Shawky::Config.mask_mode)
    return value unless phone_like?(value)

    mask_digits(value.delete('^0-9'), mode)
  end

  # Masks phone numbers that appear inside a longer string (e.g. a contact named after its number).
  def mask_embedded(value, mode = Shawky::Config.mask_mode)
    return value unless value.is_a?(String)

    value.gsub(EMBEDDED_PHONE) { |match| mask_digits(match.delete('^0-9'), mode) }
  end

  def mask_digits(digits, mode)
    return HIDDEN if mode == 'hidden'

    (MASK_CHAR * (digits.length - 3)) + digits[-3..]
  end
end
