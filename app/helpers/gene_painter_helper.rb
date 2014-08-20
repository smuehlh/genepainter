require 'genestructures.rb'

module GenePainterHelper

  def create_data_center_table(seq_names)
    table_body = ''

    seq_names.each { |name|
      table_body += '<tr>'
        table_body += '<td>' + check_box_tag("analyze", nil, true) + '</td>'
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
    f_path = "#{controller.f_dest}/gene_structures/#{filename}"
    return get_status_of_gene_structure(f_path).to_s
  end

  def get_sequence_names(filename)
    sequence_names = "<table id='sequence_names'>"

    File.open(filename, "r").each_line do |line|
      tokens = line.gsub(/\s+/, ' ').strip.split(' ')
      sequence_names << "<tr><td>#{tokens.first}</td></tr>"
    end

    # dummy row
    sequence_names << "<tr><td>&nbsp;</td></tr>"

    sequence_names << "</table>"
    return sequence_names
  end

  def get_table(filename, table_name)
    table = "<table id='#{table_name}'>"

    File.open(filename, "r").each_line do |line|
      table << "<tr>"

      tokens = line.gsub(/\s+/, ' ').strip.split(' ')
      tokens[1].split(//).each do |char|
        table << "<td>#{char}</td>"
      end

      table << "</tr>"
    end

    table << "</table>"
    return table
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

    all_gene_structures = Dir["#{controller.f_dest}/gene_structures/*.yaml"]
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
