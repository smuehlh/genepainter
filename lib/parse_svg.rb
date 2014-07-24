# svg parser

# this method builds a new SVG file containing only selected genestructures
# @path_to_complete_svg [String] path to SVG file containing all data
# @path_to_reduced_svg [String] path to new SVG file containing only selected genestructures
# @selected_genestructs [Array] Fasta headers that should be included in new SVG
def build_svg_by_genestructs(path_to_complete_svg, path_to_reduced_svg, selected_genestructs)
	header, footer, all_genestruct_by_name = read_genestructure_svg(path_to_complete_svg)
	reduced_svg = reduce_genestructure_svg(header, footer, all_genestruct_by_name, selected_genestructs)
	write_genestructure_svg(reduced_svg, path_to_reduced_svg)
end

# this method reads in a nested svg file and extracts the nested elements
# @path_to_svg [String] Path to nested SVG file
# returns [String] SVG header
# returns [String] SVG footer
# returns [Hash] Keys: first text in nested element, value: the complete nested element, as array
def read_genestructure_svg(path_to_svg)

	genestruct_by_name = {}
	current_name = ""
	tmp = []
	header, footer = "", ""
	is_collecting_genestructure = false
	is_collecting_legend = false

	IO.foreach(path_to_svg) do |line|
		line = line.chomp


		# collect header
		if header == "" && line.start_with?("<svg") then 
			header = line
			next
		end

		# collect genestructure or legend
		if line.start_with?("<svg") then 
			tmp = [ line ]
			next
		end
		if ! is_collecting_legend && line.start_with?("<text") then 
			current_name = line.match(/>(.*)</)[1]
			genestruct_by_name[current_name] = tmp
			genestruct_by_name[current_name].push( line )
			if current_name == "Legend" then 
				is_collecting_legend = true
			else
				is_collecting_genestructure = true
			end
			next					
		end
		if is_collecting_legend && line.start_with?("</svg") then 
			genestruct_by_name[current_name].push( line )
			is_collecting_legend = false
			next
		end
		if is_collecting_genestructure && line.start_with?("</svg") then 
			genestruct_by_name[current_name].push( line )
			is_collecting_genestructure = false
			next
		end
		if is_collecting_legend || is_collecting_genestructure then 
			genestruct_by_name[current_name].push( line )
			next
		end

		# collect footer
		if line.start_with?("</svg") then 
			footer = line
			next
		end
	end

	return header, footer, genestruct_by_name
end

# this method creates an SVG as array consiting of selected (nested) elements only
# @header [String] SVG header
# @footer [String] SVG footer
# @all_genestruct_by_name [Hash] nested SVG elements, keys: first text in nested element
# @selected_names_for_output [Array] gene names (should be keys in all_genestruct_by_name)
# returns [Array] SVG containing only selected_names_for_output
def reduce_genestructure_svg(header, footer, all_genestruct_by_name, selected_names_for_output)
	svg = []

	height_per_genestruct = calc_height_per_genestructure(all_genestruct_by_name)
	height_legend = calc_legend_height(all_genestruct_by_name["Legend"], header)
	total_height = selected_names_for_output.size * height_per_genestruct + height_legend

	svg.push( set_height(header, total_height) )
	y_pos = 0.0
	selected_names_for_output.each do |name|
		svg_data = all_genestruct_by_name[name]
		if svg_data then 
			svg.push( set_y_pos(svg_data, y_pos) )
			y_pos += height_per_genestruct
		end
	end
	svg.push( set_y_pos(all_genestruct_by_name["Legend"], y_pos) )
	svg.push( footer )

	return svg
end
# this method writes an array to file
# @svg [Array] data to write
# @output_path [String] Path to output file
def write_genestructure_svg(svg, output_path)
	IO.write( output_path, svg.join("\n"), :mode => "w" )
end
# this method calculates the height (y-axis in SVG) per genestructure (i.e. per nested SVG element)
# @genestruct_by_name [Hash] all nested elements
# returns [FixNum] height per genestrucuture
def calc_height_per_genestructure(genestruct_by_name)
	first_svg_pos, second_svg_pos = nil, nil
	legend_pos = nil
	genestruct_by_name.each do |name, svg_data|
		if name == "Legend" then 
			# nothing to do
		else
			svg_pos = get_y_pos(svg_data)
			if ! first_svg_pos then 
				first_svg_pos = svg_pos
			elsif first_svg_pos && ! second_svg_pos then 
				second_svg_pos = svg_pos
			elsif svg_pos < first_svg_pos then 
				second_svg_pos = first_svg_pos
				first_svg_pos = svg_pos
			elsif  svg_pos > first_svg_pos && svg_pos < second_svg_pos then 
				second_svg_pos = svg_pos
			end	
		end			
	end
	return second_svg_pos - first_svg_pos
end
# this method calculated the height of the legend by substracting the start height position from the total height
# @svg_data [Array] a nested element, containing Legend data
# @header [String] the SVG header
# returns [FixNum] height of legend
def calc_legend_height(svg_data, header)
	start_heigth = get_y_pos(svg_data)
	total_height = get_height(header)
	return total_height - start_heigth
end
# this method returns the y-axis position of a nested SVG element
# @svg_data [Array] nested svg element
# returns [FixNum] y-axis position
def get_y_pos(svg_data)
	y_pos = svg_data.first.match(/y=\"([\.\d]+)\"/)[1] 
	return y_pos.to_f
end
# this method changes the y-axis position of a nested SVG element
# @svg_data [Array] nested svg element
# @y_pos [FixNum] new y-axis position
# returns [Array] nested svg element with new y-axis position
def set_y_pos(svg_data, y_pos)
	first_line = svg_data.shift
	new_first_line = first_line.sub(/y=\"[\.\d]+\"/, "y=\"#{y_pos}\"")
	return svg_data.unshift( new_first_line )
end
# this method returns the height of the SVG 
# @header [String] SVG header element
# returns [FixNum] height of SVG
def get_height(header)
	y_pos = header.match(/height=\"([\.\d]+)\"/)[1]
	return y_pos.to_f
end
# this method changes the height of the SVG, also in viewbox
# @header [String] SVG header element
# @y_pos [FixNum] new height
# returns [String] SVG header with new height
def set_height(header, y_pos)
	new_header = header.sub(/height=\"[\.\d]+\"/, "height=\"#{y_pos}\"")
	viewbox = header.match(/viewBox=\"([^\"]+)/)[1]
	new_viewbox = viewbox.sub(/\s[\.\d]+$/, " #{y_pos}")
	return new_header.sub(viewbox, new_viewbox)
end
