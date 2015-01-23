module SequenceHelper

	extend self

	# this method parses a multiple sequence alignment and extracts headers and sequences
	# @path [String] path to multiple sequence alignment file
	# returns [Array] headers, in same order as sequences
	def read_in_alignment(path)
		names, seqs = [], []
		IO.foreach(path) do |line|
			line = line.chomp
			next if line.empty?

			if line.start_with? ">" then
				# fasta header
				names << line[1..-1]
			else
				# fasta sequence
				n_seqs = names.size
				# a new sequence or another line for the last sequence?
				if seqs.size < n_seqs then
					# new sequence
					seqs << line
				end
			end
		end
		names.delete("")
		seqs.delete("")
		if names.size != seqs.size then
			raise "Error while parsing multiple sequence alignment. Number of fasta header and sequences does not match." 
		elsif names.size == 0 
			raise "Error while parsing multiple sequence alignment. Must contain at least one sequence."
		end
		return names, seqs
	end

	def speciesname_to_fastaheader(str)
		">" + str
	end

	# this method parses a file with mapping between species and genes
	# @path [String] path to mapping file
	# returns [Hash] keys: gene names (i.e. fasta headers), values: corresponding species
	def map_genenames_to_speciesnames(path)
		genes_with_corresponding_species = {}
		IO.foreach(path) do |line|
			line = line.chomp
			next if line.empty? 

			parts = line.split(/:/x) # ignore white spaces surrounding ":"
			genes = parts.shift
			species = parts.join(":")

			if genes.nil? || species.nil? || genes.blank? || species.blank? then
				raise "Error while parsing mapping between species and genes. Expecting \':\'-separated list of genes and species"
			end
			species = species.strip # remove leading & trailing white spaces
			species = species.gsub(/\A"|"\Z/, '') # remove leading * trailing quotes
			genes = genes.split(/[,|;]/).map { |g| g.strip } # remove leading & trailing white spaces

			genes.each do |gene|
				if ! genes_with_corresponding_species[gene] then 
					genes_with_corresponding_species[gene] = species
				end
			end
		end

		return genes_with_corresponding_species
	end
end