module Shawky::Patches::ConversationDrop
  def contact_name
    value = super
    Shawky::Config.enabled?(:phone_masking) ? Shawky::PhoneMask.mask_embedded(value) : value
  end
end
