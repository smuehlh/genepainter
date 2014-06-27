class GenePainterController < ApplicationController

  # Render start page for GenePainter
  def genePainter
    prepare_new_session
  end

  def upload_sequence

    # basename = File.basename(params.length)
    basename = params[:files][0].original_filename
		# save in session
		session[:file] = {name: basename}

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
