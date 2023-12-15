class User < ApplicationRecord
  validates_presence_of :bc_id, :name, :email
  validates_uniqueness_of :bc_id
end
