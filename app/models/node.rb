class Node
  include Mongoid::Document
  include Mongoid::Tree
  field :taxonomy_id, type: Integer
  field :scientific_name, type: String
  field :rank, type: String
  field :common_names, type: Array
  has_many :duplications
end
