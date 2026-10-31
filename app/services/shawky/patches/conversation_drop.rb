module Shawky::Patches::ConversationDrop
  def contact_name
    value = super
    Shawky::PhoneMask.enabled?(@obj.try(:account)) ? Shawky::PhoneMask.mask_embedded(value) : value
  end
end
