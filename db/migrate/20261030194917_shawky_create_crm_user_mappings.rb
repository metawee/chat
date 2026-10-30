class ShawkyCreateCrmUserMappings < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_crm_user_mappings do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: true
      t.string :crm_user_id, null: false
      t.timestamps
    end
    add_index :shawky_crm_user_mappings, [:account_id, :crm_user_id], unique: true
  end
end
