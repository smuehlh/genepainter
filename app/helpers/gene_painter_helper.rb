module GenePainterHelper

  def class_intron_col(n_introns)
    "intron-col-" + n_introns.to_s
  end

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
  # table for data center
  def prepare_table_body(col1_data, col1_data_with_species, col1_data_with_genestruct)
    content_tag(:tbody) do 
      col1_data.sort.each.collect do |gene|
        species, status_genestruct = "", ""
        style_generate_genestruct = "display: none;" 
        if col1_data_with_species[gene] then 
          species = col1_data_with_species[gene]
          style_generate_genestruct = "" # species info present, so its ok to display checkbox
        end
        if col1_data_with_genestruct[gene] then 
          status_genestruct = col1_data_with_genestruct[gene]
          style_generate_genestruct = "display: none;" # gene structure present, so its ok to hide checkbox
        end
        content_tag(:tr) do 
          content_tag(:td, 
            check_box_tag("analyse[]", 
              gene, true, # true: is checked
              :id => "#{gene}_analyse", 
              :class => "analyse_checkbox"
            ),
            :class => "oce-checkbox-col"
          ) +
          content_tag(:td, 
            label_tag("#{gene}_analyse", gene),
            :class => "oce-text-col"
          ) +
          content_tag(:td,
            status_genestruct.html_safe,
            :class => "oce-text-col",
            :id => "#{gene}_status"
          ) +
          content_tag(:td,
            check_box_tag("generate_genestruct[]", 
              gene, nil, 
              :id => "#{gene}_generate", 
              :style => style_generate_genestruct,
              :class => "generate_checkbox",
              :title => "Provide species mapping to enable checkbox."
            ),
            :class => "oce-broad-checkbox-col"
          ) +
          content_tag(:td,
            species.html_safe +
            hidden_field_tag( "species[]",
              species, 
              :id => "#{gene}_hidden"
            ),
            :class => "oce-species-col",
            :id => "#{gene}_species"
          )
        end
      end.join.html_safe
    end
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

    sequence_names << "</table>"
    return sequence_names
  end

  def get_statistics_table(filename, id_patterns_table)

    names_table, pattern_table, stats_table, stats_table_head, intronpos_table = [], [], [], [], []

    names_table << "<table>"
    pattern_table << "<table id=#{id_patterns_table} class='with_border'>"
    stats_table_head << "<table>"
    stats_table << "<table>"
    intronpos_table << "<table class='with_border'>"

    first_char_pattern_line = ">" # each line of exon-intron patterns should start with ">"
    first_chars_intronpos_line = ">Intron" # line containing intron numbers
    first_chars_merged_line = ">Merged" # line containing merged pattern
    is_first_stats_line = true
    zero_based_intron_count = 0 # for stats -table

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
        data = parts.map.each_with_index do |ele, ind|
          if ind == 0 then 
            this_class = "stats-intron-count-col"
          elsif ind == 1
            this_class = "stats-intron-num-col"
          elsif ind == 2
            this_class = "stats-taxon-col"
          else
            this_class = ""      
          end
          "<td class=\"#{this_class}\">#{ele}</td>"
        end

        if is_first_stats_line then
          # use table head element
          data = data.map{ |ele| ele.gsub("td", "th") }    
          stats_table_head.push "<tr>"
          stats_table_head.push data
          stats_table_head.push "</tr>"
          is_first_stats_line = false
        else
          # use table data element
          this_class = class_intron_col(zero_based_intron_count) 
          stats_table.push "<tr class=\"#{this_class}\">"
          zero_based_intron_count += 1
          stats_table.push data
          stats_table.push "</tr>"
        end
      end
    end

    pattern_table << "</table>"
    names_table << "</table>"
    stats_table_head << "</table>"
    stats_table << "</table>"
    intronpos_table << "</table>"

    return names_table.join.html_safe, pattern_table.join.html_safe, 
      stats_table_head.join.html_safe, stats_table.join.html_safe, 
      intronpos_table.join.html_safe
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

  def copy_alignment_for_lucullus(file_src)
    file_id = "genepainter#{controller.id}"
    file_dest = File.join(Dir::tmpdir, "cymobase_alignment_#{file_id}.fasta")

    headers, seqs = SequenceHelper.read_in_alignment(file_src)
    headers.map!{ |e| ">" << e } # add ">" again to make it a valid header

    # delete additonal patterns
    ind = headers.index{|ele|ele =~/>Consensus/}
    if ind then 
      headers.delete_at(ind)
      seqs.delete_at(ind)
    end
    ind = headers.index{|ele|ele =~/>Merged/}
    if ind then 
      headers.delete_at(ind)
      seqs.delete_at(ind)
    end

    fh_dest = File.new(file_dest, 'w')
    fh_dest.puts( headers.zip(seqs).flatten.join("\n") )
    if headers.size > 22 then 
      # QUICK-FIX to Lucullus-Bug
      # add a faked last sequence, to make sure all real sequences are visible
      # only if there were too many sequences in the first place (22 ist just a rough estimate)
      fh_dest.puts( ">." )
      fh_dest.puts( "." * seqs[0].size )
    end

    fh_dest.close

    return file_id
  end
  def render_lucullus_iframe(fileid)
      iframe_src = Lucullus_url + "?source=#{fileid}"
      return content_tag(:iframe, "Loading ...", :src => iframe_src,
        :width => "700px", :class => "res_height", :id => "lucullus_alignment_frame")
  end

  def render_svg(filename, classname)
    svg_path = File.join("#{Rails.root}/public/tmp", filename)
    svg = File.open(svg_path, 'rb').read.delete!("\n")
    return content_tag(:div, svg.html_safe, :class => classname)
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

    data.push "<tr>"
    pattern.each_char do |char|
      if char == "-" then
        # exon
        data.push "<td>&nbsp;</td>"
      else
        data.push "<td>#{n_introns}</td>"
        n_introns += 1
      end
    end

    data.push "</tr>"
    return data
  end
end
