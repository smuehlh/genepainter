module PdbParser

	extend self

	def get_chains(filename)
		chains = []
		IO.foreach(filename) do |line|
			if line.start_with?("ATOM") then 
				parts = line.split(/\s+/)
	            # make sure that accessing field 4 of array parts will work
	            next if parts.size <= 5
				chains |= [ parts[4].upcase ]
			end
		end
		return chains
	end

end