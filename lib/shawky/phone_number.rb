# Normalizes a phone number to E.164. Local numbers without a country code are Egyptian.
module Shawky::PhoneNumber
  DEFAULT_COUNTRY = :EG

  module_function

  def e164(raw)
    number = raw.to_s.strip
    number = "+#{number.delete_prefix('00')}" if number.start_with?('00')
    parsed = TelephoneNumber.parse(number, number.start_with?('+') ? nil : DEFAULT_COUNTRY)
    parsed.e164_number if parsed.valid?
  end
end
