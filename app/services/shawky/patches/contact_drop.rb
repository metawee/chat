# Liquid variables ({{contact.phone_number}}) must not put the real number into messages.
module Shawky::Patches::ContactDrop
  %i[name first_name last_name].each do |attribute|
    define_method(attribute) do
      value = super()
      Shawky::PhoneMask.enabled?(@obj.try(:account)) ? Shawky::PhoneMask.mask_embedded(value) : value
    end
  end

  def phone_number
    value = super
    Shawky::PhoneMask.enabled?(@obj.try(:account)) ? Shawky::PhoneMask.mask(value) : value
  end
end
