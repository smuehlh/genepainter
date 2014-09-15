require 'genestructures.rb'
require File.join(Dir_gene_painter, "lib/geneAlignment.rb")
module GenePainterHelper

  def create_data_center_table(seq_names)
    table_body = ''

    seq_names.each { |name|
      table_body += '<tr>'
        table_body += '<td>' + check_box_tag("analyze", name, true) + '</td>'
        table_body += '<td style="text-align: left">' + name + '</td>'

        # All gene structures are missing if no files are uploaded
        table_body += '<td><span id="' + name + '">missing</span></td>'
        table_body += '<td>' + check_box_tag("generateGeneStructure", name, nil, :disabled => true) + '</td>'

        # table_body += '<td style="text-align: left">' + map[name].to_s  + '</td>'
        table_body += "<td style=\"text-align: left\" data=\"#{name}\" id=\"species\"></td>"

      table_body += '</tr>'
    }

    return table_body
  end

  # Returns gene structure status
  def gene_structure_status(filename)
    f_path = File.join( controller.p_gene_structures, filename)
    return get_status_of_gene_structure(f_path).to_s
  end

  def get_sequence_names(filename)
    sequence_names = "<table id='sequence_names'>"

    File.open(filename, "r").each_line do |line|

      name = line[0...GeneAlignment.max_length_gene_name].strip
      sequence_names << "<tr><td>#{name}</td></tr>"
    end

    # dummy row
    sequence_names << "<tr><td>&nbsp;</td></tr>"

    sequence_names << "</table>"
    return sequence_names
  end

  def get_statistics_table( filename, stats_table_id)

    stats_table = ["<table id=#{stats_table_id}>"]

    first_char_pattern_line = ">" # each line of exon-intron patterns should start with ">"
    is_first_stats_line = true
    IO.foreach(filename) do |line|
      line = line.chomp
      next if line.empty?

      if line.start_with?(first_char_pattern_line) then 
        # exon-intron pattern

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

    stats_table.push("</table>")
    return stats_table.join.html_safe
  end

  def get_table(filename, table_name, opts={})
    table = "<table id='#{table_name}'>"
    is_first_line = true
    n_cols = 0

    File.open(filename, "r").each_line do |line|

      table << "<tr>"

      pattern = line[GeneAlignment.max_length_gene_name..-1].strip
      pattern.split(//).each do |char|
        table << "<td>#{char}</td>"
      end
      if is_first_line then
        # count number of columns in first line
        n_cols = pattern.size
        is_first_line = false
      end

      table << "</tr>"
    end

    if opts[:col_group_class] then 
      # add colgroup with class opts[:col_group_class]
      puts "++++++"
      puts "use colgroup"
      table << "<colgroup>"
      0.upto(n_cols) do 
        table << "<col class=\"#{opts[:col_group_class]}\">"
      end
      table << "</colgroup>"
    end

    table << "</table>"

    if ! opts[:intron_numbers_table] then
      # don't generate additional table
      
      return table

    else
      # generate additional table with intron numbers, return both!
      intron_num_table = "<table id='#{opts[:intron_numbers_table]}'>"
      if opts[:col_group_class] then 
        # add colgroup
        intron_num_table << "<colgroup>"
        0.upto(n_cols) do 
          intron_num_table << "<col class=\"#{opts[:col_group_class]}\">"
        end
        intron_num_table << "</colgroup>"
      end
      intron_num_table << "</table>"

      return table, intron_num_table

    end
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
        :width => "675px", :height => "200px", :id => "lucullus_alignment_frame")
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

end
