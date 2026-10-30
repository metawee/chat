class ShawkyCreateCrmActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_crm_activities do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: true
      t.string :event_id, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: 'pending'
      t.jsonb :payload, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.string :last_error
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :shawky_crm_activities, :event_id, unique: true
    add_index :shawky_crm_activities, [:conversation_id, :kind, :created_at]
  end
end
