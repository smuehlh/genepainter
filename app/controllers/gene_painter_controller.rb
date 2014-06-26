class GenePainterController < ApplicationController

  # Render start page for GenePainter
  def genePainter

  end

  def upload_file
    render js: "alert('Hello Rails');"
  end

end
