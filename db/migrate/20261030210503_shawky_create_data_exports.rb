class ShawkyCreateDataExports < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_data_exports do |t|
      t.references :account, null: false, index: true
      t.references :user, null: false, index: false
      t.date :from_date, null: false
      t.date :to_date, null: false
      t.string :file_format, null: false
      t.boolean :include_phone_numbers, null: false, default: false
      t.string :status, null: false, default: 'pending'
      t.timestamps
    end
  end
end
