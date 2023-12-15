class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :bc_id
      t.string :name
      t.string :email

      t.timestamps
    end
  end
end
