require 'parse_data.rb'

class GenePainterController < ApplicationController

  # Render start page for GenePainter
  def genePainter
    prepare_new_session
  end

  def upload_sequence
    @basename = params[:files][0].original_filename
    path = params[:files][0].path()

    @seq_names = read_in_alignment(path)[0]

    respond_to do |format|
      format.js
    end
  end

	# prepare a new session
	def prepare_new_session
		reset_session
	    session[:file] = {}
	end
end
