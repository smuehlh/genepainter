require 'parse_data.rb'

class GenePainterController < ApplicationController

  # Render start page for GenePainter
  def gene_painter
    prepare_new_session
  end

  def upload_sequence
    @fatal_error = catch(:error) {
      @basename = params[:files][0].original_filename
      path = params[:files][0].path()

      @seq_names = read_in_alignment(path)[0]

      [] # default for @fatal_error
    }

  	rescue RuntimeError => exp
  		@fatal_error = [exp.message]

  	rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
  		@fatal_error = ["Cannot load file.", "Please contact us."]

  	ensure
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
