module GenePainterHelper

  @@seq_names = ["HsCoro1A", "HsCoro1B", "HsCoro1D"]

  def add_species()
    space = "margin-right: 20px"

    seq_names_list = ""
    @@seq_names.each do |seq_name|
      seq_names_list << content_tag(:li, check_box_tag("seq_name", seq_name) + content_tag(:span, seq_name))
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
        :style => space + "; width: 150px; height: 50px; overflow: auto; display:inline-block"
      )
    )
  end

end
