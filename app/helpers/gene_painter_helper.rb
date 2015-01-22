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

    classes_per_column = convert_intron_numbers_to_classes(introns_per_column, true) # true: use only intronpos-class

    pattern_table = build_pattern_table(pattern_data, classes_per_column, 
      {id: id_pattern_table, classes: 'with_border'} 
    )
    names_table = build_table(names_data)
    intronpos_table = build_intronpos_table(intronpos_data, {id: id_intronpos_table, classes: 'with_border'})

    stats_only_th_table = build_stats_table(stats_head, true) # true: use th tag
    stats_only_td_table = build_stats_table(stats_data, false) # false: use tr tag

    return pattern_table, names_table, intronpos_table, stats_only_th_table, stats_only_td_table
  end

  def get_fuzzy_table_and_info(filename, id_pattern_table, id_merged_table)
    pos_with_fuzzy = {}
    pattern_data, names_data = [], [] # names data not acutally needed
    introns_per_column = nil # init with nil, will be converted to array later ...

    is_collected_fuzzy_pos = false

    IO.foreach(filename) do |line|
      line = line.chomp
      next if line.empty?

      if line[0] == ">" && is_collected_fuzzy_pos then 
        # pattern, with fuzzy pos merged, treat as pattern in get_table method
        introns_per_column = init_intron_counts(line) if introns_per_column.nil?
        update_wanted_data(line, pattern_data, names_data, introns_per_column)

      elsif is_fuzzy_pos_list(line)
        # table with mapping of fuzzy positions
        update_fuzzy_pos(line, pos_with_fuzzy)
        is_collected_fuzzy_pos = true
      end
    end

    classes_per_column = convert_fuzzy_intron_numbers_to_classes(introns_per_column, pos_with_fuzzy)

    pattern_table = build_pattern_table(pattern_data, classes_per_column, {id: id_pattern_table})
    merged_table = build_merged_pattern_table(introns_per_column, id_merged_table)

    return pattern_table, merged_table, pos_with_fuzzy
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

    classes_per_column = convert_intron_numbers_to_classes(introns_per_column)

    pattern_table = build_pattern_table(pattern_data, classes_per_column, {id: id_pattern_table})
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

  def convert_intron_numbers_to_classes(introns_per_column, is_only_intronpos_classes=false)
    classes_arr = Array.new(introns_per_column.size, "")

    intronpos = 0 # first intron has class intron_0 !
    introns_per_column.each_with_index do |n_introns, ind|
      if is_only_intronpos_classes then 
        this_classes = ""
      else
        this_classes = "col-#{n_introns}"
      end
      if n_introns > 0 then 
        # intron position in any pattern, not neccessarily this pattern
        this_classes += " #{class_intron_col(intronpos)}"
        intronpos += 1
      end
      classes_arr[ind] = this_classes
    end

    return classes_arr
  end

  def convert_fuzzy_intron_numbers_to_classes(introns_per_column, fuzzy_pos)
    classes_arr = Array.new(introns_per_column.size, "")

    intronpos = 0 # first intron has class intron_0
    introns_per_column.each_with_index do |n_introns, ind|
      this_classes = "col-#{n_introns}"

      if n_introns > 0 then 
        this_intron_col_class = class_intron_col(intronpos)

        # add own intronpos- class
        this_classes += " #{this_intron_col_class}"
        intronpos += 1

        # add all merged intronpos-classes
        if mapped_classes = fuzzy_pos[this_intron_col_class] then    
          mapped_classes.each do |this_class|      
            this_classes += " #{this_class}"
            intronpos += 1
          end 
        end
      end

      classes_arr[ind] = this_classes
    end
    return classes_arr
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

  def update_fuzzy_pos(line, pos_with_fuzzy)
    parts = line.split("\t")

    ref = parts[0].to_i - 1 # -1: convert human to ruby counting
    mapped_pos = parts[1].split(/,\s*/).map {|num| num.to_i - 1 } # -1 convert human to ruby counting

    pos_with_fuzzy[class_intron_col(ref)] = mapped_pos.map{|num| class_intron_col(num)}
  end
  def is_fuzzy_pos_list(line)
    parts = line.split("\t")
    # line contains a tab-separated table (in fuzzy output, only fuzzy-table itself does)
    return parts.size == 2 && parts[0].to_i != 0
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

  def build_pattern_table(data, classes_per_col, opts={})
    open_tag = "<table"
    open_tag += " id='#{opts[:id]}'" if opts[:id] && opts[:id] != ""
    open_tag += " class='#{opts[:classes]}'" if opts[:classes] && opts[:classes] != ""
    open_tag += ">"
    table = [ open_tag, nil, "</table>" ]
    table[1] = data.collect do |datum|
      pattern_to_tr(datum, classes_per_col)
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
    # use intron counts as they are as class!
    table = ["<table id='#{id}'>", pattern_to_tr(pattern, introns_per_column), "</table>"]
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
  def pattern_to_tr(pattern, classes_per_col)
    res = ["<tr>", nil, "</tr>"]
    intronpos = 0 # first intron has class intron_0 !
    res[1] = pattern.each_with_index.collect do |char, ind|
      classes = classes_per_col[ind]
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
