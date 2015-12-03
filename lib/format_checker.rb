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
	def validate_genestructure_type(path, file_extension)
		Helper.file_exist_or_die(path)
		known_extensions = [ ".yaml", ".gff", ".gff3" ] # must be in lower case!, as file will be converted to lower case, too

		if ! known_extensions.include? file_extension then 
			# file extension does not match
			Helper.raise_runtime_error "Expecting gene structure in YAML or GFF format."
		end
	end

	# basic validation for gene structures
	# checks if GenePainter can handle file
	def validate_genestructure_content(genestruc_path, alignment_path, file_basename, file_extension)
		genestruct = IO.read(genestruc_path)
		full_name = "#{file_basename}#{file_extension}"

		# 0) is there an aligned seq for the gene structure?
		begin 
			aligned_seq = SequenceHelper.get_aligned_seq_by_name(alignment_path, file_basename)
		rescue 
			Helper.raise_runtime_error "Cannot upload file #{full_name}. Gene is not in alignment."
		end	

		# 1) is gene structure file (roughly) in the correct format?
		if file_extension == ".yaml" then 
			# test for yaml-format
			kind = ToGene.is_yaml(genestruct, file_basename)
			if kind == "yaml" then 
				# yes, file is a valid

				# 2) test if aligned sequence matches gene structure
				yaml_seq = ToGene.get_yaml_seq(genestruct, file_basename)
				if ! ToGene.does_yamlseq_matches_aligned_seq(yaml_seq, aligned_seq) then 
					Helper.raise_runtime_error "Cannot upload file #{full_name}. Gene structure and aligned sequence do not match."
				end

			elsif kind == "not-yaml"
				Helper.raise_runtime_error "Cannot upload file #{full_name}. File is not a valid YAML file."
			elsif kind == "yaml-wrong-genename"
				found_genstructs = ToGene.get_genestructs_in_yaml(genestruct)
				Helper.raise_runtime_error "Cannot upload file #{full_name}. File does not contain gene structure #{file_basename}. (Found instead: #{found_genstructs}.)"
			end

		else
			# test for gff-format
			kind = ToGene.is_gff(genestruct)
			if kind == "gff" then 
				# not possible to test if aligned seq matches gff.
				# nothing to do
			else
				Helper.raise_runtime_error "Cannot upload file #{full_name}. File is not a valid GFF file."
			end	
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

class ToGene
	def self.is_yaml(genestruct, genename)
		begin 
			contigs = YAML.load( genestruct )
			if contigs && contigs.kind_of?(Hash) && ! (contigs[genename] || contigs["ScipioResult"]) then 
				return "yaml-wrong-genename"
			end
			if contigs && contigs.any? then 
				return "yaml"
			end
			return "not-yaml"
		rescue
			return "not-yaml"
		end
	end
	def self.get_genestructs_in_yaml(genestruct)
		contigs = YAML.load( genestruct )
		if contigs.kind_of?(Hash) then 
			return contigs.keys.join(", ")
		else
			return "-"
		end
	end
	def self.does_yamlseq_matches_aligned_seq(yaml_seq, aligned_seq)
		# mimic formatting of queryseq done by scipio:
		scipio_formatted_alignment_seq = aligned_seq.upcase
		scipio_formatted_alignment_seq = scipio_formatted_alignment_seq.gsub("*", "X")
		scipio_formatted_alignment_seq = scipio_formatted_alignment_seq.gsub(/[^ACDEFGHIKLMNPQRSTVWYX]/, "")

		return scipio_formatted_alignment_seq == yaml_seq 
	end
	def self.get_yaml_seq(genestruct, genename)
		contigs = YAML.load( genestruct )
		if contigs[genename] then
			# replace collection of gene structures by the one of interest
			contigs = contigs[genename]
		elsif contigs["ScipioResult"]
			# this yaml was downloaded by WebScipio, but is perfectly valid
			contigs = contigs["ScipioResult"]
		end
		return contigs.collect{|contig| contig["prot_seq"]}.join
	end

	def self.is_gff(genestruct)
		gff = genestruct.lines
		if gff.any? {|line| line.include?("ScipioResult")} then
			# gff is obtained from Scipio (and does not follow standard format)
			cds_lines = gff.select {|line| line.match("protein_match")}
		else
			first_mRNA_line = gff.find {|line| line.match("mRNA")}
			first_mRNA_id = nil # default: use every CDS description line
			if first_mRNA_line then 
				first_mRNA_id = get_id_from_attributes(first_mRNA_line)
			end
			cds_lines = gff.select do |line|
				line.match("CDS") && is_child_of(line, first_mRNA_id)
			end
		end
		if cds_lines.any? then 
			return "gff"
		else
			return "not-gff"
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