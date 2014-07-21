require 'parse_data.rb'
require 'genestructures.rb'
require 'parse_svg.rb'
require 'helper.rb'

class GenePainterController < ApplicationController

  @@f_dest = ''
  @@f_gene_structures = ''
  @@default_fname = ''

  @@seq_names = []
  @@name_species_map = {}

  def f_dest
    @@f_dest
  end

  def f_gene_structures
    @@f_gene_structures
  end

  def seq_names
    @@seq_names
  end

  def name_species_map
    @@name_species_map
  end

  # Render start page for GenePainter
  def gene_painter

    # Generate a dir in tmp to store uploaded files
    id = Helper.make_new_tmp_dir(TMP_PATH)

    @@f_dest = File.join(TMP_PATH, id)
    @@default_fname = File.join(@@f_dest, 'alignment')
    @@f_gene_structures = File.join(@@f_dest, 'gene_structures')

    Helper.mkdir_or_die(@@f_gene_structures)

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
      Helper.move_or_copy_file(path, @@f_dest, 'move')

      # rename to original name
      Helper.rename(File.join(@@f_dest, File.basename(path)),
        File.join(@@f_dest, @basename))

      # call fromdos
      is_sucess = system('fromdos',@@f_dest)
      throw :error, ['Cannot upload file', 'Please contact us.'] if ! is_sucess

      [] # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = [exp.message]

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
      @fatal_error = ['Cannot load file.', 'Please contact us.']

    ensure
      @@seq_names = @seq_names

      respond_to do |format|
        format.js
      end
  end

  def upload_gene_structures
    @fatal_error = catch(:error) {
      file = params[:files][0]

      # check file size
      Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)
      Helper.move_or_copy_file(file.path(), @@f_gene_structures, 'move')

      # rename to original name
      Helper.rename(File.join(@@f_gene_structures, File.basename(file.path())),
        File.join(@@f_gene_structures, file.original_filename))

			# call fromdos
			is_sucess = system('fromdos',@@f_dest)
			throw :error, ['Cannot upload file', 'Please contact us.'] if ! is_sucess

      [] # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = [exp.message]

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
      @fatal_error = ['Cannot load file.', 'Please contact us.']

    ensure
      respond_to do |format|
        format.js
      end
  end

  def upload_species_mapping
    @fatal_error = catch(:error) {
      file = params[:files][0]
      @basename = file.original_filename
      path = file.path()

      # check file size
      Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

      # store file in place
      Helper.mkdir_or_die(@@f_dest)
      Helper.move_or_copy_file(path, @@f_dest, 'move')

      # rename to original name
      Helper.rename(File.join(@@f_dest, File.basename(path)),
        File.join(@@f_dest, @basename))

      # call fromdos
      is_sucess = system('fromdos',@@f_dest)
      throw :error, ['Cannot upload file', 'Please contact us.'] if ! is_sucess

      [] # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = [exp.message]

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
      @fatal_error = ['Cannot load file.', 'Please contact us.']
      # @fatal_error = [exp.message]

    ensure
      map_sequence_name_to_species

      respond_to do |format|
        format.js
      end
  end

  def create_alignment_file
    sequence_string = params[:sequence]
    @errors = []

    begin
      # Use default filename
      if File.exist?(@@default_fname)
        f = File.open(@@default_fname, 'w+')
      else
        f = File.new(@@default_fname, 'w+')
      end

      if File.writable?(f)
        f.write(sequence_string)
      end
      f.close

      @seq_names = read_in_alignment(@@default_fname)[0]
    rescue  NoMethodError => ex
      @errors << 'Error parsing sequence alignment'
    rescue RuntimeError, Errno::ENOENT, NameError => ex
      @errors << ex.message
    ensure
      respond_to do |format|
        format.js
      end
    end

  end

  def map_sequence_name_to_species
    @@name_species_map = map_genenames_to_speciesnames(@@f_dest + '/fastaheaders2species.txt')
  end

  def create_gene_structures
    neededGeneStructures = params[:data] == nil ? [] : params[:data]
    path_to_species_to_fasta = @@f_dest + '/fastaheaders2species.txt'

    # Get all files with extension .fas
    paths = Dir[@@f_dest + '/*.fas']
    path_to_fasta = paths[0]

    output_path = File.join(@@f_dest, 'gene_structures')

    @retValue, @generatedGeneStructures = generate_gene_structures(neededGeneStructures, path_to_species_to_fasta, path_to_fasta, output_path)

    @generatedGeneStructures.collect! {
      |gGS| File.basename(gGS, '.*')
    }

    # /fab8/server/db_scripts/gene_painter_new/gene_painter$

    # Generate svg output files


    ensure
      respond_to do |format|
        format.js
      end
  end

end
