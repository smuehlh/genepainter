require 'parse_data.rb'
require 'helper.rb'

class GenePainterController < ApplicationController

  @@f_dest = ""
  @@f_mode = 0444

  def self.f_dest
    @@f_dest
  end

  def self.f_mode
    @@f_mode
  end

  # Render start page for GenePainter
  def gene_painter
    prepare_new_session

    id = Helper.make_new_tmp_dir(TMP_PATH)
    @@f_dest = File.join(TMP_PATH, id)
  end

  def upload_sequence
    @fatal_error = catch(:error) {
      file = params[:files][0]
      @basename = file.original_filename
      path = file.path()

      @seq_names = read_in_alignment(path)[0]

      # check file size
      Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

      # store file in place
      Helper.mkdir_or_die(@@f_dest)
      Helper.move_or_copy_file(path, @@f_dest, "move")

      # rename to original name
      Helper.rename(File.join(@@f_dest, File.basename(path)),
        File.join(@@f_dest, @basename))

      # call fromdos
      is_sucess = system("fromdos",@@f_dest)
      throw :error, ["Cannot upload file", "Please contact us."] if ! is_sucess

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

  def upload_gene_structures
    @fatal_error = catch(:error) {
      file = params[:files][0]

      # check file size
      Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

      gene_structures_path = File.join(@@f_dest, "gene_structures")

      # store file in place
			Helper.mkdir_or_die(gene_structures_path)
      Helper.move_or_copy_file(file.path(), gene_structures_path, "move")

      # rename to original name
      Helper.rename(File.join(gene_structures_path, File.basename(file.path())),
        File.join(gene_structures_path, file.original_filename))

      # Helper.chmod(@@f_dest, @@f_mode)
      # Will handle eventually. Need to comment out to upload multiple files.

			# call fromdos
			is_sucess = system("fromdos",@@f_dest)
			throw :error, ["Cannot upload file", "Please contact us."] if ! is_sucess

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
