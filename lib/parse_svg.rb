# svg parser

# this method builds a new SVG file containing only selected genestructures
# @path_to_complete_svg [String] path to SVG file containing all data
# @path_to_reduced_svg_genenames [String] path to new SVG file containing only names of selected genes
# @path_to_reduced_svg_genestructures [String] path to new SVG file containing only structures of selected genes; not starting at left -border!!
# @path_to_reduced_svg_legend [String] path to new SVG file containing only legend
# @selected_genestructs [Array] Fasta headers that should be included in new SVG
# returns true if SVG files were generated, false otherwise
def build_svg_by_genestructs(path_to_complete_svg, 
		path_to_reduced_svg_genenames, path_to_reduced_svg_genestructures, path_to_reduced_svg_legend,
		selected_genestructs
		)

	@svg_params = get_svg_parameters_from_genepainter

	header, footer, all_genestruct_by_name, legend_genestruct = read_genestructure_svg(path_to_complete_svg)

	selected_genestruct_by_name = reduce_genestruct_by_name_to_selected_ones(all_genestruct_by_name, selected_genestructs)

	genenames, genestructures, legend = create_genestruct_names_legend_svg(
		selected_genestruct_by_name, legend_genestruct, header, footer )

	write_svg(genenames, path_to_reduced_svg_genenames)
	write_svg(genestructures, path_to_reduced_svg_genestructures)
	write_svg(legend, path_to_reduced_svg_legend)

	return true

rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
	return false
end

# this method gets the parameters used by genepainters'svg class
# returns [Hash] Parameters describing values needed to redraw (and fix sizes and positions) SVG 
def get_svg_parameters_from_genepainter

	require File.join(Dir_gene_painter, "lib/svg.rb")

	return { 
		x_pos_genename: Svg.parameters[:x_pos_genename],
		x_pos_genestruct: Svg.parameters[:distance_genename_to_gene],
		gene_height: Svg.parameters[:height_per_gene],
		legend_height: Svg.parameters[:height_per_gene] * Svg.ratios[:legend_to_gene] 
	}
end

# this method reads in a nested svg file and extracts the nested elements
# @path_to_svg [String] Path to nested SVG file
# returns [String] SVG header
# returns [String] SVG footer
# returns [Hash] Keys: first text in nested element, value: the complete nested element, as array
# returns [Array]: SVG nested element of legend
def read_genestructure_svg(path_to_svg)

	genestruct_by_name, legend_genestruct = {}, []
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

	legend_genestruct = genestruct_by_name.delete("Legend") { |ele| [] } # returns empty array if no "legend" key found

	return header, footer, genestruct_by_name, legend_genestruct
end

# this method reduces genestructures to selected ones
# @all_genestruct_by_name [Hash] SVG elements associated with gene-names
# @selected_names_for_output [Array] List of gene-names
# returns [Hash] SVG elements associated with gene-names, reduced to @selected_names_for_output
def reduce_genestruct_by_name_to_selected_ones(all_genestruct_by_name, selected_names_for_output)
	all_genestruct_by_name.select { |name, svg_data| selected_names_for_output.include?(name) }
end

# this method splits genestructures reduced to selected ones (!) into svgs for gene-name, gene-structures, and legend
# @genestructures_by_name [Hash] SVG elements associated with gene-names; not containing Legend
# @legend [Array] SVG elements associated with legend
# @header [String] SVG header (original file); height info needs to be adjusted
# @footer [String] SVG footer (original file)
# returns [Array] all SVG elements (including header and footer) for gene-names; starts at left border
# returns [Array] all SVG elements (including header and footer) for gene-structures; does not start at left border
# returns [Array] all SVG elemetns (including header and footer) for legend; starts at left border
def create_genestruct_names_legend_svg(genestructures_by_name, legend, header, footer )
	svg_names, svg_structs, svg_legend = [], [], []

	height_data = genestructures_by_name.size * @svg_params[:gene_height]
	height_legend = @svg_params[:legend_height]

	# split gene structures into names and structures, fix x- and y-positions
	y_pos = 0.0

	genestructures_by_name.each do |name, svg_data|
		data_fixed_y_pos = set_y_pos( svg_data, y_pos)

		# split svg_data into name and structure, fix x-position
		data_fixed_y_pos.each do |svg_ele|

			if svg_ele.start_with?("<svg") then 
				# svg elements for nested structure: must go into names and structs SVG
				name_ele_fixed_x_pos = set_x_pos(svg_ele, @svg_params[:x_pos_genename] * -1)
				struct_ele_fixed_x_pos = set_x_pos(svg_ele, @svg_params[:x_pos_genestruct] * -1)

				svg_names.push name_ele_fixed_x_pos
				svg_structs.push struct_ele_fixed_x_pos

			elsif svg_ele.start_with?("</svg")
				svg_names.push svg_ele
				svg_structs.push svg_ele

			elsif svg_ele.start_with?("<text") 
				# text element: goes only in names SVG; no need to fix x-pos; offset was already set in nested-svg header
				svg_names.push svg_ele

			else
				# other element: goes only in structs SVG
				# no need to fix x-position, because offset was already set in nested-SVG header
				svg_structs.push svg_ele

			end
					
		end

		y_pos += @svg_params[:gene_height]
	end

	# legend, fix y-position
	if legend.any? then 
		y_pos = 0.0
		svg_legend.push set_y_pos(legend, y_pos)
	end

	# add headers and footers to SVG arrays
	data_header_fixed_height = set_height(header, height_data)
	legend_header_fixed_height = set_height(header, height_legend)
	svg_names.unshift( data_header_fixed_height )
	svg_structs.unshift( data_header_fixed_height )
	svg_legend.unshift( legend_header_fixed_height )

	svg_names.push( footer )
	svg_structs.push( footer )
	svg_legend.push( footer )

	return svg_names, svg_structs, svg_legend

end

# this method writes an array to file
# @svg [Array] data to write
# @output_path [String] Path to output file
def write_svg(svg, output_path)
	IO.write( output_path, svg.join("\n"), :mode => "w" )
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
# this method changes the x-axis position of a nested SVG element
# @svg_ele [String] nested SVG element, should not have a x-value set
# @x_pos [FixNum] new x-axis position
# returns [String] nested SVG element with new x-axis position
def set_x_pos(svg_ele, x_pos)
	new_svg_ele = svg_ele.sub("<svg", "<svg x=\"#{x_pos}\"")
	return new_svg_ele
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


