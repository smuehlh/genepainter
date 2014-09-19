module FormatChecker
	extend self

	# basic validation of fasta-sequences
	# checks if first line is fasta-header and second line a fasta-sequence
	# @data [String] Fasta-formatted MSA (hopefully)
	# raises and runtime error if format does not match; returns nothing
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

	def validate_pdb(path)

	end

	def validate_yaml(path)

	end
end