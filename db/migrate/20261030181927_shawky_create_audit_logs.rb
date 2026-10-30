class ShawkyCreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_audit_logs do |t|
      t.references :account, null: false, index: true
      t.references :user, index: true
      t.string :action, null: false
      t.references :auditable, polymorphic: true, index: true
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address
      t.datetime :created_at, null: false
    end
    add_index :shawky_audit_logs, [:account_id, :action, :created_at]
  end
end
