module GenePainterHelper

  def class_intron_col(n_introns)
    "intron_" + n_introns.to_s
  end

  # creates table for manual species-mapping (link)
  # first row: multi checkbox set, 
  # second row: data
  def prepare_table_with_checkbox(data)
    content_tag(:tbody) do 
      data.each.collect do |str|
        content_tag(:tr) do 
          content_tag(:td, check_box_tag("names[]", str, nil, :id => "#{str}_link") ) +
          content_tag(:td, label_tag("#{str}_link", str) )
        end
      end.join().html_safe
    end
  end
  # creates table for manual species-mapping (unlink)
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
          # add checkbox for first gene
          content_tag(:td, 
            check_box_tag("names[]", gene, nil, :id => "#{gene}_unlink")
          ) +
          content_tag(:td, 
             label_tag("#{gene}_unlink", gene)
          )
        end + 
        # add checkboxes for all but first gene
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
        class_status_genestruct = "" # additional class to display complete in green and incomple in red
        style_analyse_checkbox, style_generate_genestruct_checkbox = "display: none;", "display: none;" 
        is_check_analyse_checkbox = nil # only checked if gene structure uploaded
        title_generate_cell = "Provide species mapping to enable option."
        # is species known?
        if col1_data_with_species[gene] then 
          species = col1_data_with_species[gene]
          style_generate_genestruct_checkbox = "" # species info present, so its ok to display checkbox
          title_generate_cell = "" # species info present, checkbox visible, so no need for a helpful tooltip
        end
        # is gene structure uploaded?
        if col1_data_with_genestruct[gene] then 
          status_genestruct = col1_data_with_genestruct[gene]
          style_generate_genestruct_checkbox = "display: none;" # hide generate-checkbox (even if species mapping is provided)
          style_analyse_checkbox = "" # display analyse-checkbox
          is_check_analyse_checkbox = true

          if status_genestruct == "complete" then 
            class_status_genestruct = "genestruct_complete"
          elsif status_genestruct == "incomplete"
            class_status_genestruct = "genestruct_incomplete"
          end 
        end
        content_tag(:tr) do 
          content_tag(:td, 
            check_box_tag("analyse[]", 
              gene, is_check_analyse_checkbox,
              :id => "#{gene}_analyse", 
              :class => "analyse_checkbox",
              :style => style_analyse_checkbox
            ),
            :class => "oce-checkbox-col"
          ) +
          content_tag(:td, 
            label_tag("#{gene}_analyse", gene),
            :class => "oce-text-col"
          ) +
          content_tag(:td,
            status_genestruct.html_safe,
            :class => "oce-text-col #{class_status_genestruct}",
            :id => "#{gene}_status"
          ) +
          content_tag(:td,
            check_box_tag("generate_genestruct[]", 
              gene, nil, 
              :id => "#{gene}_generate", 
              :style => style_generate_genestruct_checkbox,
              :class => "generate_checkbox"
            ),
            :class => "oce-broad-checkbox-col",
            :title => title_generate_cell
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

  def old_get_statistics_table(filename, id_patterns_table)

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
          pattern_table << old_pattern_to_tr(striped_pattern) # important: use pattern without white-spaces       
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

  def get_statistics_table(filename, id_pattern_table, id_intronpos_table)
    pattern_data, names_data, intronnum_data = [], [], []
    stats_data, stats_head = [], []
    introns_per_column = nil # init with nil value, 

    IO.foreach(filename) do |line|
      line = line.chomp
      next if line.empty?

      if line[0] == ">" then 
        # pattern, treat as in get_table method
        introns_per_column = init_intron_counts(line) if introns_per_column.nil?
        update_wanted_data(line, pattern_data, names_data, introns_per_column)
      else
        # statistics
        update_stats(line, stats_data, stats_head)
      end
    end
    intronpos_data = intronpos_to_pattern(introns_per_column)
    pattern_data.unshift intronpos_data
    names_data.unshift ">Intron number"

    pattern_table = build_pattern_table(pattern_data, introns_per_column, 
      {id: id_pattern_table, classes: 'with_border', is_no_col_classes: true} 
    )
    names_table = build_table(names_data)
    intronpos_table = build_intronpos_table(intronpos_data, {id: id_intronpos_table, classes: 'with_border'})

    stats_only_th_table = build_stats_table(stats_head, true) # true: use th tag
    stats_only_td_table = build_stats_table(stats_data, false) # false: use tr tag

    return pattern_table, names_table, intronpos_table, stats_only_th_table, stats_only_td_table
  end

  def get_table(filename, opts={})
    is_return_merged_table = opts[:is_merged_table]
    id_pattern_table = opts[:id_pattern_table] || ""

    pattern_data, names_data = [], []
    introns_per_column = nil # important: init with nil value, will be replaced by array of pattern-size

    IO.foreach(filename) do |line|
      introns_per_column = init_intron_counts(line) if introns_per_column.nil?
      update_wanted_data(line, pattern_data, names_data, introns_per_column)
    end

    pattern_table = build_pattern_table(pattern_data, introns_per_column, {id: id_pattern_table})
    names_table = build_table(names_data)
    if is_return_merged_table then 
      id_merged_table = opts[:id_merged_table] || "merged-unused-id"
      merged_table = build_merged_pattern_table(introns_per_column, id_merged_table)
      return pattern_table, names_table, merged_table
    else
      return pattern_table, names_table
    end
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
    svg_path = controller.build_output_path(filename)
    svg = File.open(svg_path, 'rb').read.delete!("\n")
    return content_tag(:div, svg.html_safe, :class => classname)
  end
  def render_tree_legend
    # build full path to load svg in both development and production mode
    svg_path = File.join( Rails.root, "app", "assets", "images", "help", "phylo_legend.svg" )
    svg = File.open(svg_path, 'rb').read.delete!("\n")
    return content_tag(:div, svg.html_safe)
  end
  def render_file(filename)    
    return File.open(filename, 'rb').read.gsub("\n", "\\n")
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

  def get_phylotree_intronpos_info(filename)
    taxa_with_gainedpos, taxa_with_allpos = {}, {}
    IO.foreach(filename) do |line|
      line = line.chomp
      match_data = line.match(/(.*):(.*):(.*)/)
      if match_data.size == 4 then 
        taxon = match_data[1]
        gained_pos = match_data[2].split(/,\s*/)
        all_pos = match_data[3].split(/,\s*/)

        taxa_with_gainedpos[taxon] = gained_pos.map{|num| class_intron_col(num)}
        taxa_with_allpos[taxon] = all_pos.map{|num| class_intron_col(num)}
      end

    end

    return taxa_with_gainedpos, taxa_with_allpos
  end

  def get_fuzzypos_info(filename)
    pos_with_fuzzy = {}
    IO.foreach(filename) do |line|
      line = line.chomp
      parts = line.split("\t")
      if parts.size == 2 && parts[0].to_i != 0 then 
        # line describes fuzzy positions:
        # pos & all pos mapped onto that
        ref = parts[0].to_i - 1 # -1: convert human to ruby counting
        mapped_pos = parts[1].split(/,\s*/).map {|num| num.to_i - 1 } # -1 convert human to ruby counting

        pos_with_fuzzy[class_intron_col(ref)] = mapped_pos.map{|num| class_intron_col(num)}
      end
    end
    return pos_with_fuzzy
  end

  ### helper methods for converting exon-intron pattern to table rows
  def split_pattern_line(line)
    name = line[0...GeneAlignment.max_length_gene_name].strip
    pattern = line[GeneAlignment.max_length_gene_name..-1].strip
    pattern = pattern.gsub(" ", "") # only statistics-pattern contains spaces, but filtering them out does not hurt!
    pattern = pattern.chars # split into array
    return pattern, name
  end
  def update_wanted_data(line, pattern_data, names_data, introns_per_column)
    pattern, name = split_pattern_line(line) # pattern is an array, name a string!
    if ! is_unwanted_data(name) then 
      collect_data(pattern, name, pattern_data, names_data)
      update_intron_counts(pattern, introns_per_column)
    end
  end
  def init_intron_counts(line)
    pattern, name = split_pattern_line(line)
    return Array.new(pattern.size, 0)
  end
  def is_unwanted_data(name)
    # special patterns should not be included in output!
    return name == (">Merged") || name.start_with?(">Consensus") || name == (">Intron")
  end
  def update_intron_counts(pattern, introns_per_column)
      pattern.each_with_index do |char, ind|
        if char != "-" then 
          # not an exon
          introns_per_column[ind] += 1
        end
      end
  end
  def collect_data(pattern, name, pattern_data, names_data)
    pattern_data.push pattern
    names_data.push name
  end

  def intronpos_to_pattern(introns_per_column)
    intronpos = 0
    return introns_per_column.collect do |n_introns|
      if n_introns == 0 then 
        dat = "&nbsp;"
      else
        dat = intronpos
        intronpos += 1
      end
      dat
    end
  end

  def update_stats(line, stats_data, stats_head)
    if stats_head.empty? then 
      # first line -> table head
      stats_head.push line.split("\t")
    else
      # any other line -> table data
      stats_data.push line.split("\t")
    end
  end
  def build_stats_table(data, is_th_tag)
    table = [ "<table>", nil, "</table>" ]
    intronpos = 0
    table[1] = data.collect do |arr|
      if is_th_tag then 
        dat = stats_to_tr(arr, "", is_th_tag) # true      
      else
        dat = stats_to_tr(arr, class_intron_col(intronpos), is_th_tag) 
        intronpos += 1
      end
      dat
    end  
    return table.join.html_safe
  end


  def build_pattern_table(data, additional_info, opts={})
    open_tag = "<table"
    open_tag += " id='#{opts[:id]}'" if opts[:id] && opts[:id] != ""
    open_tag += " class='#{opts[:classes]}'" if opts[:classes] && opts[:classes] != ""
    open_tag += ">"
    table = [ open_tag, nil, "</table>" ]
    table[1] = data.collect do |datum|
      pattern_to_tr(datum, additional_info, opts[:is_no_col_classes])
    end
    return table.join.html_safe
  end
  def build_table(data, opts={})
    open_tag = "<table"
    open_tag += " id='#{opts[:id]}'" if opts[:id] && opts[:id] != ""
    open_tag += " class='#{opts[:classes]}'" if opts[:classes] && opts[:classes] != ""
    open_tag += ">"
    table = [ open_tag, nil, "</table>" ]
    table[1] = data.collect do |datum|
      array_to_tr( [datum] ) 
    end
    return table.join.html_safe
  end
  def build_merged_pattern_table(introns_per_column, id)
    pattern = introns_per_column.collect do |n_introns|
      if n_introns == 0 then 
        # exon
        str = "-"
      else
        # intron
        str = "|"
      end
    end

    table = ["<table id='#{id}'>", merged_pattern_to_tr(pattern, introns_per_column), "</table>"]
    return table.join.html_safe
  end
  def build_intronpos_table(pattern, opts={})
    open_tag = "<table"
    open_tag += " id='#{opts[:id]}'" if opts[:id] && opts[:id] != ""
    open_tag += " class='#{opts[:classes]}'" if opts[:classes] && opts[:classes] != ""
    open_tag += ">"
    table = [open_tag, array_to_tr(pattern), "</table>"]
    return table.join.html_safe
  end
  def merged_pattern_to_tr(pattern, introns_per_column)
    res = ["<tr>", nil, "</tr>"]
    res[1] = pattern.each_with_index.collect do |char, ind|
      n_introns = introns_per_column[ind]
      "<td class='#{n_introns}'>#{char}</td>"
    end
    return res.join("")   
  end
  def pattern_to_tr(pattern, introns_per_column, is_no_col_classes)
    res = ["<tr>", nil, "</tr>"]
    intronpos = 0 # first intron has class intron_0 !
    res[1] = pattern.each_with_index.collect do |char, ind|
      n_introns = introns_per_column[ind]
      if is_no_col_classes then 
        classes = ""
      else 
        classes = "col-#{n_introns}"
      end
      if n_introns > 0 then 
        # intron position in any pattern, not neccessarily this pattern
        classes += " #{class_intron_col(intronpos)}"
        intronpos += 1
      end
      "<td class='#{classes}'>#{char}</td>"
    end
    return res.join("")
  end
  # each array element gets td
  def array_to_tr(arr)
    res = ["<tr><td>", nil, "</td></tr>"]
    res[1] = arr.join("</td><td>")
    return res.join("")
  end
  def stats_to_tr(arr, tr_class, is_use_th)
    res = ["<tr class='#{tr_class}'>", nil, "</tr>"]
    res[1] = arr.each_with_index.collect do |txt, ind|
      if ind == 0 then 
        classes = "stats-intron-count-col"
      elsif ind == 1
        classes = "stats-intron-num-col"
      elsif ind == 2
        classes = "stats-taxon-col"
      else
        classes = ""      
      end
      if is_use_th then 
        "<th class='#{classes}'>#{txt}</th>"
      else
        "<td class='#{classes}'>#{txt}</td>"
      end
    end
    return res.join("")
  end

end
