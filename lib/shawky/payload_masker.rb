# Deep-masks phone numbers in any payload (API JSON, ActionCable, webhooks).
# Masking is value-based so fields we do not know about are still covered.
# What the customer typed (message content) is left untouched.
class Shawky::PayloadMasker
  # Subtrees holding text written by the customer or agent.
  CONTENT_KEYS = %w[content processed_message_content content_attributes].freeze
  # Human-readable fields where a number may sit inside a longer string.
  EMBEDDED_KEYS = %w[name contact_name].freeze
  # Meta/Chatwoot identifiers are long digit strings but not phone numbers.
  ID_KEY = /(\A|_)id\z/
  PHONE_ID_KEYS = %w[wa_id source_id].freeze
  # Values that serialize to themselves; anything else (e.g. a record embedded in
  # push_event_data) is converted with as_json first so its attributes are masked too.
  SCALARS = [Numeric, Symbol, TrueClass, FalseClass, NilClass, Date, Time, ActiveSupport::TimeWithZone].freeze

  def self.call(payload, exempt: [])
    new(exempt).mask(payload)
  end

  def initialize(exempt)
    @exempt = exempt.to_set { |number| number.to_s.delete('^0-9') }
    @mode = Shawky::Config.mask_mode
  end

  def mask(value, key = nil)
    case value
    when Hash then mask_hash(value)
    when Array then value.map { |item| mask(item, key) }
    when String then mask_string(value, key)
    when *SCALARS then value
    else mask(value.as_json, key)
    end
  end

  private

  def mask_hash(hash)
    hash.to_h { |key, value| [key, CONTENT_KEYS.include?(key.to_s) ? value : mask(value, key.to_s)] }
  end

  def mask_string(value, key)
    return value if key&.match?(ID_KEY) && PHONE_ID_KEYS.exclude?(key)
    return value if @exempt.include?(value.delete('^0-9'))
    return Shawky::PhoneMask.mask_embedded(value, @mode) if EMBEDDED_KEYS.include?(key)

    Shawky::PhoneMask.mask(value, @mode)
  end
end
