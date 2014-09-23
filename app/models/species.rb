# species model
class Species
	include Mongoid::Document
	include Autocomplete

	field :scientific_name, type: String
end
