# A CRM lead as the Shawky gateway (and n8n) send it, and where its fields live on the contact.
module Shawky::Lead
  ID_KEY = 'crm_lead_id'.freeze
  # lead field => contact custom attribute
  CONTACT_ATTRIBUTES = {
    'name' => 'crm_name', 'salesman' => 'salesman', 'project' => 'project', 'status' => 'status', 'channel' => 'channel',
    'created_at' => 'crm_created_at', 'site_state' => 'site_state', 'area' => 'area', 'cs_agent' => 'cs_agent',
    'lead_id' => ID_KEY, 'extra' => 'crm_extra'
  }.freeze

  module_function

  def id(contact)
    contact.custom_attributes[ID_KEY]
  end

  # Copies the lead onto the contact's custom attributes; an empty value never replaces a filled one.
  def merge_into(custom_attributes, lead)
    CONTACT_ATTRIBUTES.each_with_object((custom_attributes || {}).dup) do |(field, attribute), merged|
      value = lead[field]
      merged[attribute] = value if value.present?
    end
  end
end
