class AddNameToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column(:users, :name, :string, limit: 50, null: false, default:'')
  end
end
