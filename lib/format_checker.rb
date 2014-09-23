module FormatChecker
	extend self

	# basic validation of fasta-sequences
	# checks if first line is fasta-header and second line a fasta-sequence
	# @data [String] Fasta-formatted MSA (hopefully)
	# raises runtimeError if format does not match; returns nothing
	def validate_fasta(data)
		if data.start_with?(">") then 
			# first line is (or rather, seems to be) fasta header
			if data.lines.size == 1 || data.lines[1].chomp.match(/[^A-Z*-]/) then 
				# second line is not a fasta-sequence
				Helper.raise_runtime_error "Expecting fasta-formatted multiple sequence alignment."
			end
		else
			# does not start with fasta-header
			Helper.raise_runtime_error "Expecting fasta-formatted multiple sequence alignment."
		end
	end

	# basic validation for PDB
	# checks if file extension matches pdb
	# checks if very first line starts with string "HEADER"
	# raises runtimeError if format does not match, returns nothing
	def validate_pdb(path, filename)
		Helper.file_exist_or_die(path)
		if ! File.extname(filename).downcase == ".pdb" then 
			Helper.raise_runtime_error "Expecting PDB file."
		else
			first_line = File.head(path, 1)[0]
			if ! first_line.start_with?("HEADER") then 
				Helper.raise_runtime_error "Expecting PDB file." 
			end
		end
	end

	# basic validation for gene structures
	# checks if file extension matches yaml or gff
	# other than that, nothing can be checked, as webscipio-generated files does not quite follow standards
	# raises runtimeError if format does not match, returns nothing
	def validate_genestructure(path, filename)
		Helper.file_exist_or_die(path)
		known_extensions = [ ".yaml", ".gff" ] # must be in lower case!, as filename will be converted to lower case, too
		if ! known_extensions.include? File.extname(filename).downcase then 
			# file extension does not match
			Helper.raise_runtime_error "Expecting gene structure in YAML or GFF format."
		end
	end

	# basic validation for species mapping
	# checks if file can be converted into map of genes and species
	# raises runtimeError if format does not match, returns nothing
	def validate_speciesmapping(path)
		Helper.file_exist_or_die(path)
		begin
			SequenceHelper.map_genenames_to_speciesnames( path )
		rescue RuntimeError
			# replace error message by parser with own error message
			Helper.raise_runtime_error "Expecting colon-separated list of gene(s) and species."
		end
	end

end

class File
	# reads n lines from top of file
	def self.head(path, n=1)
		open(path) do |file|
			lines = Array.new(n)
			n.times do |i|
				line = file.gets || break
				lines[i] = line
			end
			lines
		end
	end
end