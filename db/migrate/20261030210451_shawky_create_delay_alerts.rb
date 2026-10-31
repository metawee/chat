class ShawkyCreateDelayAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_delay_alerts do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: false
      t.references :assignee, null: false, index: false
      t.datetime :waiting_since, null: false
      t.references :reassigned_to, index: false
      t.timestamps
    end
    # One alert per waiting customer message.
    add_index :shawky_delay_alerts, [:conversation_id, :waiting_since], unique: true
  end
end
