class Store < ApplicationRecord
  has_many :users

  validates_presence_of :access_token, :store_hash
  validates_uniqueness_of :store_hash
end
