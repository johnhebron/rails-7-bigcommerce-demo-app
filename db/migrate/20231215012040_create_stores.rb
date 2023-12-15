class CreateStores < ActiveRecord::Migration[7.1]
  def change
    create_table :stores do |t|
      t.integer :user_id
      t.string :scopes
      t.string :store_hash
      t.string :access_token
      t.boolean :is_installed

      t.timestamps
    end
  end
end
