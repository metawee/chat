class ShawkyCreateTeamSupervisors < ActiveRecord::Migration[7.2]
  def change
    create_table :shawky_team_supervisors do |t|
      t.references :account, null: false, index: true
      t.references :team, null: false, index: true
      t.references :user, null: false, index: true
      t.timestamps
    end
    add_index :shawky_team_supervisors, [:team_id, :user_id], unique: true
  end
end
