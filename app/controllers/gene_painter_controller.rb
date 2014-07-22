require 'parse_data.rb'
require 'genestructures.rb'
require 'parse_svg.rb'
require 'helper.rb'

class GenePainterController < ApplicationController

  @@id = ''
  @@f_dest = ''
  @@f_gene_structures = ''
  @@default_fname = ''

  @@seq_names = []
  @@name_species_map = {}

  def id
    @@id
  end

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

    @@id = @@f_dest.split('/').last

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

    missing_gene_structures = params[:data] == nil ? [] : params[:data]

    alignment_files = Dir[@@f_dest + '/*.fas']
    f_alignment = alignment_files.first

    # Path to dir that contains gene structures
    d_gene_structures = File.join(@@f_dest, 'gene_structures')

    # Path to gene_painter.rb
    f_gene_painter = '/fab8/server/db_scripts/gene_painter_new/gene_painter/gene_painter.rb'

    # Path to output dir
    d_output = "#{Rails.root}/public/tmp"

    # Prefix to all output files
    prefix = @@id

    f_species_to_fasta = Dir[@@f_dest + '/fastaheaders2species.txt']

    if f_species_to_fasta.blank?
      logger.debug("Didn't find any fastaheaders2species files.")

      # Call gene_painter
      @retVal_no_taxonomy = system "ruby #{f_gene_painter} -i #{f_alignment} -p #{d_gene_structures} --outfile #{prefix} --path-to-output #{d_output} --intron-phase --phylo --spaces --alignment --svg --svg-format both --svg-merged --svg-nested --statistics"

      logger.debug(@retVal_no_taxonomy)

    else


    end

    #
    # @retValue, @generatedGeneStructures = generate_gene_structures(neededGeneStructures, path_to_species_to_fasta, path_to_fasta, output_path)
    #
    # @generatedGeneStructures.collect! {
    #   |gGS| File.basename(gGS, '.*')
    # }

    # /fab8/server/db_scripts/gene_painter_new/gene_painter$

    # Call gene_painter.rb

    # Check if there is a species mapping file
    # species_mapping_files = Dir[@@f_dest]


    ensure
      respond_to do |format|
        format.js
      end
  end

end
