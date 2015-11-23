module GenePainterHelper

  def class_intron_col(n_introns)
    "intron_" + n_introns.to_s
  end
  def exon_placeholder 
    "-"
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

  # parse exonintronpattern table from file
  # return genenames & patterns as array
  # no need to deal with number of introns, or merged pattern, or... as this can be extraced from array
  def parse_exonintronpattern(filename)
    data = []
    IO.foreach(filename) do |line|
      if is_pattern(line) then 
        parts = pattern_line_to_arr(line)
        data.push parts
      end
    end
    return data
  end

  def parse_statspattern(filename)
    pattern = []
    stats = [] 
    IO.foreach(filename) do |line|
      # file consists of two parts:
      # part 1: normal pattern
      if is_pattern(line) then 
        parts = pattern_line_to_arr(line)
        pattern.push parts
      end

      # part 2: list with statistics 
      if is_table(line) then 
        parts = table_line_to_arr(line)
        stats.push parts
      end

    end
    return pattern, stats
  end

  def parse_fuzzypattern(filename)
    pattern = []
    pos = nil # init with nil to separate between normal pattern and fuzzy-pattern (follows after fuzzy pos)
    IO.foreach(filename) do |line|
      # file consists of three parts:
      # part 1: normal pattern
      # nothing to do

      # part 2: list with fuzzy positions
      if is_table(line) then 
        if pos.nil? then 
          # this is first table line -> the header -> do not collect data
          pos = init_fuzzypos # re-do init
          next
        end
        parts = table_line_to_arr(line)
        key = parts.shift
        val = parts.shift

        # convert key to zero-based number; convert values to zero-based list
        pos[human_to_ruby_counting(key)] = list_to_ruby_counts(val)
      end

      # part 3: pattern with fuzzy positions merged
      # follows fuzzy-pos list! (opposed to part 1)
      if is_pattern(line) && ! pos.nil? then       
        parts = pattern_line_to_arr(line)
        pattern.push parts
      end
    end
    return pattern, pos
  end
  def init_fuzzypos
    # "need" this method as fuzzypos should be initialized from view and from this helper
    return {}
  end
  def add_class_info_to_fuzzy_pos(hash)
    # add intron-index classes to position data
    hash.keys.each do |key|
      values = hash[key]
      hash["intron_#{key}"] = values.map{|num| "intron_#{num}"}
      hash.delete(key) # delete old key-value pair
    end
    return hash
  end

  def parse_svg(filename)
    data = [""]
    IO.foreach(filename) do |line|
      line = line.chomp
      data[0] += line
    end
    return data
  end

  def data_to_th(arr)
    table_rows = []
    arr.each do |row|
      tr = "<tr>"

      row.each do |cell|
        tr += "<th>#{cell}</th>"
      end

      tr += "</tr>"
      table_rows.push tr

    end
    return table_rows.join
  end

  # convert data to tr-data
  # input: array of arrays
  # converts only wanted columns!
  # use number of introns in row & intron position as classes 
  # assume first cell = name; all other cells = exons/introns
  # classes:
  # col-X -> the number of introns in the respective table column (appliccable for exons and introns)
  # intron_X -> the index of the intron (only for intron-columns)
  def data_to_tr(arr)
    table_rows = []

    patterns = arr.collect{ |inner_arr| inner_arr[1..-1] }
    intron_numbers = pattern_to_intron_numbers(patterns) # number of introns per column
    intron_indices = pattern_to_intron_indices(patterns) # index of introns in row

    arr.each do |row|
      tr = "<tr>"

      name = row[0]
      pattern = row[1..-1]

      tr += "<td class='genename'>#{name}</td>"
      pattern.each_with_index do |cell, ind|
        this_class = "col-#{intron_numbers[ind]}"
        this_class += " intron_#{intron_indices[ind]}" if intron_indices[ind]  

        tr += "<td class='#{this_class}'>#{cell}</td>"
      end
     
      tr += "</tr>"
      table_rows.push tr

    end
    return table_rows.join
  end

  # convert stats data to tr-data
  # classes: depending on first column (= intron index + 1)
  # intron_X -> intron index 
  def stats_data_to_tr(arr)
    table_rows = []

    patterns = arr.collect{ |inner_arr| inner_arr[1..-1] }

    arr.each do |row|
      tr = "<tr>"

      intron = row[0]
      pattern = row[1..-1]

      this_class = "intron_#{human_to_ruby_counting( intron.to_i )}" 
      tr += "<td class='#{this_class}'>#{intron}</td>"
      pattern.each_with_index do |cell, ind|
        tr += "<td class='#{this_class}'>#{cell}</td>"
      end
     
      tr += "</tr>"
      table_rows.push tr

    end
    return table_rows.join    
  end

  # convert fuzzy data to tr-data
  # classes:
  # col-X -> number of introns in the respective table column
  # intron_X -> intron index _of the standard, un-fuzzy pattern_ 
  def fuzzy_data_to_tr(arr, fuzzy_pos)
    table_rows = []

    patterns = arr.collect{ |inner_arr| inner_arr[1..-1] }
    intron_numbers = pattern_to_intron_numbers(patterns) # number of introns per column
    intron_indices = pattern_to_fuzzy_intron_indices(patterns, fuzzy_pos) # index/indices (if merged fuzzy pos) of introns

    arr.each do |row|
      tr = "<tr>"

      name = row[0]
      pattern = row[1..-1]

      tr += "<td class='genename'>#{name}</td>"
      pattern.each_with_index do |cell, ind|
          this_class = "col-#{intron_numbers[ind]}"
          intron_indices[ind].each do |thisind|
            this_class += " intron_#{thisind}"
          end

        tr += "<td class='#{this_class}'>#{cell}</td>"
      end
    
      tr += "</tr>"
      table_rows.push tr

    end
    return table_rows.join
  end

  def data_to_merged_tr(arr)
    table_rows = []

    name = "Merged"
    patterns = arr.collect{ |inner_arr| inner_arr[1..-1] }
    intron_numbers = pattern_to_intron_numbers(patterns)

    # empty tr
    tr = pattern_to_dummy_tr(patterns[0])
    table_rows.push tr

    # data tr
    tr = "<tr>"
    tr += "<th class='genename'>#{name}</th>"

    pattern_to_merged(patterns).each_with_index do |cell, pattern_ind|
      this_class = intron_numbers[pattern_ind]
      if this_class then 
        tr += "<th class='#{this_class}'>#{cell}</th>"
      else
        tr += "<th>#{cell}</th>"
      end
    end

    tr += "</tr>"
    table_rows.push tr
    return table_rows.join
  end

  def data_to_intronindex_tr(arr)
    table_rows = []

    name = "Intron number"
    patterns = arr.collect{ |inner_arr| inner_arr[1..-1] }

    # empty tr
    tr = pattern_to_dummy_tr(patterns[0])
    table_rows.push tr

    # data tr
    tr = "<tr>"
    tr += "<th class='genename'>#{name}</th>"

    pattern_to_intron_indices(patterns).each do |ind|
      if ind then 
        num = ruby_to_human_counting(ind)
        tr += "<th class=intron_#{ind}>#{num}</th>"
      else
        tr += "<th>&nbsp;</th>"  
      end
    end

    tr += "</tr>"
    table_rows.push tr
    return table_rows.join
  end

  # get number of introns at each position
  def pattern_to_intron_numbers(arr)
    first_row = arr[0]
    return first_row.each_with_index.collect do |cell, ind_col|
      col = arr.collect{|row| row[ind_col]} 
      col.select{|e| e != exon_placeholder }.size # assue every non-exon is an intron!
    end
  end

  # get index of intron at each position 
  def pattern_to_intron_indices(arr)
    ind = -1 # start with -1 as ind is incremented before collect -> the effective, first ind is 0

    first_row = arr[0]
    return first_row.each_with_index.collect do |cell, ind_col|
      col = arr.collect{|row| row[ind_col]} 
      n_introns = col.select{|e| e != exon_placeholder }.size # assume every non-exon is an intron!

      if n_introns == 0 then 
        # an exon column -> no intron-index
        nil
      else
        # an intron column
        ind += 1 
        ind 
      end
    end
  end

  # get index of intron/ indices of merged introns at each position in merged arr
  def pattern_to_fuzzy_intron_indices(arr, fuzzy_pos)
    res = []
    ind = 0 
    first_row = arr[0]
    first_row.each_with_index do |cell, ind_col|
      col = arr.collect{|row| row[ind_col]} 
      n_introns = col.select{|e| e != exon_placeholder }.size # assume every non-exon is an intron!
      this_res = []

      if n_introns == 0 then 
        # exon column -> no intron index
      else
        # intron column
        this_res.push ind

        # fuzzy pos
        if fuzzy_pos[ind] then 
          this_res.push *fuzzy_pos[ind] # * for element-wise appending array
          ind += fuzzy_pos[ind].size
        end 

        ind += 1 
      end
      res.push this_res
    end

    return res
  end

  def pattern_to_merged(arr)
    first_row = arr[0]
    return first_row.each_with_index.collect do |cell, ind_col|
      col = arr.collect{|row| row[ind_col]} 
      col = col.uniq - [exon_placeholder] # (different) intron placeholders remain
      if col.size == 0 then 
        # no intron at all
        exon_placeholder
      elsif col.size == 1 
        # intron, all of same kind (phase)
        col[0]
      else
        # introns of different phase. should never happen...
        "?"
      end
    end
  end

  def pattern_to_dummy_tr(arr)
    tr = "<tr>"
    tr += "<th class='genename tfoot-spacer'>&nbsp;</th>"
    arr.each do |cell|
      tr += "<th class='tfoot-spacer'>&nbsp;</th>"
    end
    tr += "</tr>"
    return tr
  end

  def copy_alignment_for_lucullus(file_src)
    file_id = "genepainter#{controller.id}"
    file_dest = File.join(Dir::tmpdir, "cymobase_alignment_#{file_id}.fasta")

    headers, seqs = SequenceHelper.read_in_alignment(file_src)
    headers.map!{ |e| SequenceHelper.speciesname_to_fastaheader(e) } # add ">" again to make it a valid header

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
    content = []
    n_lines = 0
    IO.foreach(filename) do |line|
      content << line.chomp
      n_lines += 1
      break if n_lines > 500
    end
    if n_lines > 500 then 
      content << "[Skipped rest of file ...]"
    end

    return content.join("\\n")
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

  # helper methods for parsing exon-intron patterns to table data
  def pattern_line_to_arr(line)
    name = line[0...GeneAlignment.max_length_gene_name].strip
    pattern = line[GeneAlignment.max_length_gene_name..-1].strip
    pattern = pattern.gsub(" ", "") # only statistics-pattern contains spaces, but filtering them out does not hurt!
    pattern = pattern.chars # split into array
    return [name, pattern].flatten
  end
  def table_line_to_arr(line)
    parts = line.split("\t")
    return parts.collect do |str|
      str.strip
    end
  end
  def list_to_ruby_counts(str)
    parts = str.split(",")
    return parts.collect do |str|
      str = str.strip
      if str.to_i != 0 then 
        # assume that a) line contains numbers, but b) no zero-numbers as 
        # c) numbers are in human counting
        human_to_ruby_counting(str)
      else
        str 
      end    
    end
  end
  def is_pattern(line)
    # special patterns should not be included in output!
    return ( line.start_with?(">") &&
      ! ( line.start_with?(">Merged") || line.start_with?(">Consensus") || line.start_with?(">Intron") )
      )
  end
  def is_table(line)
    # line contains a tab-separated table, with at least two columns ?
    parts = line.split("\t")
    return parts.size >= 2     
  end
  def human_to_ruby_counting(num)
    num.to_i - 1
  end
  def ruby_to_human_counting(num)
    num.to_i + 1
  end

end
