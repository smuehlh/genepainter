require 'mongoid'

module Autocomplete
  extend ActiveSupport::Concern

  included do
    field :autocomplete
    before_save :generate_autocomplete
  end

  # callback to populate :autocomplete
  def generate_autocomplete
    s = self.scientific_name
    # truncate strings, replace last char with "" instead of default "..." [omission]
    s = s.truncate(50, omission: "", separator: " ") if s.length > 50
    write_attribute( :autocomplete, Autocomplete.normalize(s) )
  end

  # turn strings into autocomplete keys
  def self.normalize(s)
    s = s.upcase
    s = s.gsub("'", "")
    s = s.gsub(/[^A-Z0-9 ]/, " ")
    s = s.squish # chomps string, and change consecutive whitespaces into single
    s = " #{s}" # start with whitespace to allow for fast prefix-matching
    return s
  end

  def self.search(query)
    query = normalize(query)
    return [] if query.blank?
    Species.where(autocomplete: /#{query}/).asc(:scientific_name).limit(20)
  end
end

# species model
class Species
	include Mongoid::Document
	include Autocomplete

	field :scientific_name, type: String
end

Mongoid.load!("/fab8/mgoetts/import_ncbi/mongoid.yml", "MONGOID_ENV")
Mongoid.connect_to("ncbi_import_development")

taxonomy = File.open("/fab8/mgoetts/import_ncbi/taxonomy_filtered.txt", "rb") { |f| Marshal.load(f) }

taxonomy.each do |key, attrs|
	if attrs[:rank] =~ /species/i then 
		s
		Species.create( scientific_name: attrs[:scientific_name] )
	end
end

in case first population was without autocomplete, add autocompletion 