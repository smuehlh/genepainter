module GenePainterHelper

  # creates table,
  # first row: multi checkbox set, 
  # second row: data
  def prepare_table_with_checkbox(data)
    content_tag(:tbody) do 
      data.each.collect do |str|
        content_tag(:tr) do 
          content_tag(:td, check_box_tag("names[]", str, nil, :id => "#{str}_link") ) +
          content_tag(:td, str.html_safe)
        end
      end.join().html_safe
    end
  end
  # data [Hash]: keys: col1 (might span multiple columns, values: col2 (checkbox; multi-select per col1 value) + col3
  def prepare_table_with_checkbox_and_span_columns(data)

    col1_data = data.keys.sort
    content_tag(:thead, escape: false) do 
      content_tag(:tr) do 
        content_tag(:th, "Species") +
        content_tag(:th, "Gene", :colspan => 2)
      end
    end +
    content_tag(:tbody) do 
      col1_data.each.collect do |species|
        genes = data[species].sort
        gene = genes.shift
        content_tag(:tr, :class => "with_border") do 
          content_tag(:td, species, :rowspan => genes.size + 1) + # +1 to account for shifted gene
          content_tag(:td, 
            check_box_tag("names[]", gene, nil, :id => "#{gene}_unlink")
          ) +
          content_tag(:td, 
             label_tag("#{gene}_unlink", gene)
          )
        end + 
        genes.each.collect do |gene|
          content_tag(:tr) do 
            content_tag(:td, 
              check_box_tag("names[]", gene, nil, :id => "#{gene}_unlink")
            ) +
            content_tag(:td, 
               label_tag("#{gene}_unlink", gene)
            )
          end
        end.join.html_safe
      end.join.html_safe
    end
  end

  def create_data_center_table(seq_names)
    table_body = ''

    seq_names.each { |name|
      table_body += '<tr>'
        table_body += '<td class="oce-checkbox-col">' + check_box_tag("analyze", name, true) + '</td>'
        table_body += '<td class="oce-small-text-col">' + name + '</td>'

        # All gene structures are missing if no files are uploaded
        table_body += '<td class="oce-small-text-col"><span id="' + name + '">missing</span></td>'
        table_body += '<td class="oce-checkbox-col">' +
            check_box_tag("generateGeneStructure", name, nil, :disabled => true,
              :title => "Provide species mapping to enable checkbox.",
            ) +
          '</td>'

        # table_body += '<td style="text-align: left">' + map[name].to_s  + '</td>'
        table_body += "<td data=\"#{name}\" id=\"species\" class=\"oce-species-col\"></td>"

      table_body += '</tr>'
    }

    return table_body
  end

  # Returns gene structure status
  def gene_structure_status(filename)
    f_path = File.join( controller.p_gene_structures, filename)
    return GenestructureHelper.get_status_of_gene_structure(f_path).to_s
  end

  def get_sequence_names(filename)
    sequence_names = "<table id='sequence_names'>"

    File.open(filename, "r").each_line do |line|

      name = line[0...GeneAlignment.max_length_gene_name].strip
      if name =~ /^>Merged/ || name =~ /^>Consensus/ then 
        # special pattern, do not include in text-based output!
        next
      end

      sequence_names << "<tr><td>#{name}</td></tr>"
    end

    # issue4
    # # dummy row
    # sequence_names << "<tr><td>&nbsp;</td></tr>"

    sequence_names << "</table>"
    return sequence_names
  end

  def get_statistics_table(filename, id_patterns_table)

    names_table, pattern_table, stats_table, intronpos_table = [], [], [], []

    names_table << "<table>"
    pattern_table << "<table id=#{id_patterns_table} class='with_border'>"
    stats_table << "<table>"
    intronpos_table << "<table class='with_border'>"

    first_char_pattern_line = ">" # each line of exon-intron patterns should start with ">"
    first_chars_intronpos_line = ">Intron number" # line containing intron numbers
    first_chars_merged_line = ">Merged" # line containing merged pattern
    is_first_stats_line = true

    IO.foreach(filename) do |line|
      line = line.chomp
      next if line.empty?

      if line.start_with?(first_char_pattern_line) then 
        # exon-intron pattern

        name = line[0...GeneAlignment.max_length_gene_name].strip
        pattern = line[GeneAlignment.max_length_gene_name..-1] # important: do not strip pattern
        striped_pattern = pattern.gsub(" ", "")

        if name.start_with?(first_chars_merged_line) then 

          intronpos_table << merged_pattern_to_intronpos( striped_pattern )

          # make intron numbers first pattern in names and patterns table 
          names_table.insert( 1, "<tr><td>&gt;Intron number</td></tr>" )
          pattern_table.insert( 1, merged_pattern_to_intronpos(striped_pattern )  )

        elsif name.start_with?(first_chars_intronpos_line)

        else
          # "normal pattern" line
          names_table << "<tr><td>#{name}</td></tr>"
          pattern_table << pattern_to_tr(striped_pattern) # important: use pattern without white-spaces
        end

      else
        # data statistics

        parts = line.split("\t")
        stats_table.push "<tr>"
        if is_first_stats_line then 
          # use table head element
          data = parts.map{ |ele| "<th>#{ele}</th>"}
          is_first_stats_line = false
        else
          # use table data element
          data = parts.map{ |ele| "<td>#{ele}</td>" }
        end
        stats_table.push data
        stats_table.push "</tr>"
      end
    end

    pattern_table << "</table>"
    # # dummy row
    # names_table << "<tr><td>&nbsp;</td></tr>"
    names_table << "</table>"
    stats_table << "</table>"
    intronpos_table << "</table>"

    return names_table.join.html_safe, pattern_table.join.html_safe, stats_table.join.html_safe, intronpos_table.join.html_safe

  end

  def get_table(filename, opts={})
    table_head_str = "<table"
    table_head_str << " class='#{opts[:table_class]}'" if opts[:table_class]
    table_head_str << " id='#{opts[:table_id]}'" if opts[:table_id]
    table_head_str << ">"
    table = [ table_head_str ]

    is_first_line = true

    File.open(filename, "r").each_line do |line|

      name = line[0...GeneAlignment.max_length_gene_name].strip
      if name =~ /^>Merged/ || name =~ /^>Consensus/ then 
        # this is a special pattern, do not include it in text-based output!
        next
      end

      pattern = line[GeneAlignment.max_length_gene_name..-1].strip
      if is_first_line && opts[:colgroup_class] then 
        # get table row and generate colgroup
        table << pattern_to_colgroup( pattern, opts[:colgroup_class] )
        is_first_line = false
      end
      table << pattern_to_tr(pattern)
    end

    table << "</table>"
    return table.join.html_safe
  end


  # Converts a svg file to png.
  # @return {string} new_name
  def convert_svg_to_png(filepath)
    basename = File.basename(filepath, '.svg')
    new_name = "#{basename}.png"

    new_path = File.join("#{Rails.root}/public/tmp", new_name)

    retVal = system "convert #{filepath} #{new_path}"

    if retVal
      return new_name
    else
      return nil
    end
  end

  def copy_alignment_for_lucullus(file_src)
    file_id = "genepainter" + rand(1000000000).to_s
    file_dest = File.join(Dir::tmpdir, "cymobase_alignment_#{file_id}.fasta")
    FileUtils.cp(file_src, file_dest)
    return file_id
  end
  def render_lucullus_iframe(fileid)
      iframe_src = Lucullus_url + "?source=#{fileid}"
      return content_tag(:iframe, "Loading ...", :src => iframe_src, 
        :width => "700px", :height => "400px", :id => "lucullus_alignment_frame")
  end

  def render_svg(filename)
    svg_path = File.join("#{Rails.root}/public/tmp", filename)
    return File.open(svg_path, 'rb').read.delete!("\n")
  end

  def render_img(filename, class_name)
    return image_tag("/tmp/#{controller.id}-#{filename}", :class => class_name)
  end

  def convert_svg_to_pngs
    convert_svg_to_png("#{Rails.root}/public/tmp/#{controller.id}-genenames-normal.svg")
    convert_svg_to_png("#{Rails.root}/public/tmp/#{controller.id}-genestructures-normal.svg")

    convert_svg_to_png("#{Rails.root}/public/tmp/#{controller.id}-genenames-reduced.svg")
    convert_svg_to_png("#{Rails.root}/public/tmp/#{controller.id}-genestructures-reduced.svg")

    convert_svg_to_png("#{Rails.root}/public/tmp/#{controller.id}-legend-normal.svg")
    convert_svg_to_png("#{Rails.root}/public/tmp/#{controller.id}-legend-reduced.svg")
  end

  def populate_select_genes_modal
    table = '<table>'

    all_gene_structures = Dir["#{controller.p_gene_structures}/*.yaml"]
    all_gene_structures.map! { |gene_structure|
      File.basename(gene_structure, '.yaml')
    }

    all_gene_structures.each { |gene_structure|
      table << "<tr><td>#{check_box_tag("view", nil, false, :data => gene_structure)}</td>"
      table << "<td>#{gene_structure}</td></tr>"
    }

    table << '</table>'
  end

  def intron_numbers
    map = {}
    File.open("#{Rails.root}/public/tmp/#{controller.id}-taxonomy-intron-numbers.txt", "r").each_line do |line|
      tokens = line.strip.split(':')

      class_names = []
      tokens[1].split(',').each do |number|
        class_names.push("intron-col-#{number}")
      end

      map[tokens[0]] = class_names
    end

    return map
  end

  ### helper methods for converting exon-intron pattern to table rows
  def pattern_to_tr(pattern)
    data = ["<tr>"]
    pattern.each_char do |char|
      data.push "<td>#{char}</td>"
    end
    data.push "</tr>"
    return data
  end
  def pattern_to_colgroup(pattern, colgroup_class)
    data = ["<colgroup class='#{colgroup_class}'>"]
    pattern.each_char do |char|
      data.push "<col/>"
    end
    data.push "</colgroup>"
    return data
  end
  def merged_pattern_to_intronpos(pattern, opts={})
    n_introns = 1
    data = []

    # if opts[:is_displaynone] then 
    #   data << "<tr style='display:none;'>"
    # else
    #   data << "<tr>"
    # end

    pattern.each_char do |char|
      if char == "-" then 
        # exon
        data.push "<td>&nbsp;</td>"
      else
        data.push "<td>#{n_introns}</td>"
        n_introns += 1
      end
    end
    
    # if opts[:is_insert_dummy_cells] then 
    #   data << "<td>&nbsp;</td>"
    #   data << "<td>&nbsp;</td>"
    # end

    data.push "</tr>"
    return data
  end
end
