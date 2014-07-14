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

  def create_table(seq_names, map, f_dest)
    table_body = ''

    seq_names.each { |name|
      table_body += '<tr>'
        table_body += '<td>' + check_box_tag("analyze", nil, true) + '</td>'
        table_body += '<td>' + check_box_tag("view", nil, true) + '</td>'
        table_body += '<td style="text-align: left">' + name + '</td>'

        path = f_dest + '/gene_structures/' + name + '.yaml'
        gene_structure_status = get_status_of_gene_structure(path).to_s

        table_body += '<td>' + gene_structure_status + '</td>'

        if gene_structure_status == 'missing'
          table_body += '<td>' + check_box_tag("generateGeneStructure", name) + '</td>'
        else
          table_body += '<td>' + check_box_tag("generateGeneStructure", name, false, :disabled => true) + '</td>'
        end

        table_body += '<td style="text-align: left">' + map[name].to_s  + '</td>'

      table_body += '</tr>'
    }

    return table_body
  end

end
