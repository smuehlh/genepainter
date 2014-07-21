require 'genestructures.rb'

module GenePainterHelper

  def add_species(seq_names)
    space = "margin-right: 20px"

    seq_names_list = ""
    seq_names.each do |seq_name|
      seq_names_list << content_tag(:li,
        check_box_tag("seq_name", seq_name, false, :disabled => false) +
        # check_box_tag("seq_name", seq_name, false, :disabled => true) +
        "&nbsp;&nbsp;".html_safe +
        content_tag(:span, seq_name))
    end

    content_tag(:div,
      text_field_tag("species",
        nil,
        :placeholder => "Input species",
        :style => space
      ) +
      content_tag(:div,
        content_tag(:ul,
          seq_names_list.html_safe
        ),
        :style => space + "; width: 150px; height: 150px; overflow: auto; display:inline-block"
      )
    )
  end

  def create_data_center_table(seq_names, f_dest)
    table_body = ''
    viewCount = 0

    seq_names.each { |name|
      table_body += '<tr>'
        table_body += '<td>' + check_box_tag("analyze", nil, true) + '</td>'

        # Only check first 20 check boxes in View column
        if (viewCount < 20)
          viewCount += 1
          table_body += '<td>' + check_box_tag("view", nil, true) + '</td>'
        else
          table_body += '<td>' + check_box_tag("view", nil, false) + '</td>'
        end

        table_body += '<td style="text-align: left">' + name + '</td>'

        path = f_dest + '/gene_structures/' + name + '.yaml'
        gene_structure_status = get_status_of_gene_structure(path).to_s

        table_body += '<td><span id="' + name + '">' + gene_structure_status + '</span></td>'

        if gene_structure_status == 'missing'
          table_body += '<td>' + check_box_tag("generateGeneStructure", name) + '</td>'
        else
          table_body += '<td></td>'
        end

        # table_body += '<td style="text-align: left">' + map[name].to_s  + '</td>'
        table_body += "<td style=\"text-align: left\" data=\"#{name}\" id=\"species\"></td>"

      table_body += '</tr>'
    }

    return table_body
  end

  # helpers for aligned gene structures section
  def generate_text_based_output(filename)
    data = ''
    data += '<table id="text_based_output" style="display:inline-block; white-space: nowrap; margin: 5px; margin-right: 15px; border-spacing: 0; font-size: 13px;">'

    File.open(filename, "r").each_line do |line|
      tokens = line.gsub(/\s+/, ' ').strip.split(' ')
      data += '<tr>'
      data += '<td>' + tokens[0] + '</td>'

      tokens[1].split(//).each do |char|
        data += '<td>' + char + '</td>'
      end

      data += '</tr>'
    end

    data += '</table>'

    return data
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

  def render_svg(filename)
    svg_path = File.join("#{Rails.root}/public/tmp", filename)
    return File.open(svg_path, 'rb').read
  end

  def render_standard
    new_img = convert_svg_to_png('/fab8/vbui/genepainter_resources/output/svg_new/xy-normal.svg')

    if !new_img.nil?
      output = image_tag "/tmp/#{new_img}"
    else
      output = ''
    end

    output += render_svg('xy-normal-merged.svg').delete!("\n").html_safe

    return output
  end

  def render_reduced
    new_img = convert_svg_to_png('/fab8/vbui/genepainter_resources/output/svg_new/xy-reduced.svg')

    if !new_img.nil?
      output = image_tag "/tmp/#{new_img}"
    else
      output = ''
    end

    output += render_svg('xy-reduced-merged.svg').delete!("\n").html_safe

    return output
  end
end
