# The gateway identifies the CRM salesman by username (e.g. "rawda").
class ShawkyRenameCrmUserIdToCrmUsername < ActiveRecord::Migration[7.2]
  def change
    rename_column :shawky_crm_user_mappings, :crm_user_id, :crm_username
  end
end
