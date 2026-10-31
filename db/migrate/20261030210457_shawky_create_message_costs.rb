class ShawkyCreateMessageCosts < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_message_costs do |t|
      t.references :account, null: false, index: false
      t.references :inbox, null: false, index: false
      t.references :message, null: false, index: { unique: true }
      t.references :sender, index: false
      t.string :category
      t.string :pricing_type
      t.boolean :billable, null: false, default: false
      t.string :country_code
      t.datetime :sent_at, null: false
      t.timestamps
    end
    add_index :shawky_message_costs, [:account_id, :sent_at]
  end
end
