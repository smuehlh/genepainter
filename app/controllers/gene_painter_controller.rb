# require 'parse_data.rb'
# require 'genestructures.rb'
# require 'parse_svg.rb'
# # require 'helper.rb'
# require 'formatChecker.rb'

class GenePainterController < ApplicationController

  # @@id = ''
  # @@basepath_data = '' # basepath input data
  # session[:p_alignment] = '' # input data: alignment file
  # session[:p_gene_structures] = '' # input data: folder with gene structures

  # @@name_species_map = {}

  # session[:new_gene_structures] = []

  # def id
  #   @@id
  # end

  # def p_gene_structures
  #   session[:p_gene_structures]
  # end

  # def name_species_map
  #   @@name_species_map
  # end

  # def new_gene_structures
  #   session[:new_gene_structures]
  # end
  def id
    session[:id]
  end

  def p_gene_structures
    session[:p_gene_structures]
  end

  def name_species_map
    session[:genes_to_species_map]
  end

  def new_gene_structures
    session[:new_gene_structures]
  end

  # prepare a new session 
  def prepare_new_session
    reset_session
    session[:id] = "" # id used as folder and file names
    session[:basepath_data] = "" # path to folder containing input data 
    session[:p_alignment] = "" # path to file containing input alignment
    session[:p_gene_structures] = "" # path to folder containing gene structures
    session[:genes_to_species_map] = "" # hash with genes and corresponding species
    session[:p_pdb] = "" # path to PDB file
    session[:new_gene_structures] = [] # newly generated gene structures
  end

  # Render start page for GenePainter
  def gene_painter

    clean_up

    prepare_new_session

    # Generate a dir in tmp to store uploaded files
    session[:id] = Helper.make_new_tmp_dir(TMP_PATH)

    session[:basepath_data] = File.join(TMP_PATH, id)
    session[:p_alignment] = File.join(session[:basepath_data], 'input.fas')
    session[:p_gene_structures] = File.join(session[:basepath_data], 'gene_structures')
    session[:p_pdb] = File.join(session[:basepath_data], 'pdb.pdb')

    Helper.mkdir_or_die(session[:p_gene_structures])

    expires_now()

  rescue RuntimeError, NoMethodError, TypeError, NameError, Errno::ENOENT, ArgumentError, Errno::EACCES => exp
  
  end

  def get_species
    q = params[:q] == nil ? "" : params[:q]
    result = {}

    result["data"] = Node.all_of(scientific_name: /^#{q}/i).map do |node|
      node.scientific_name
    end
  rescue RuntimeError, NoMethodError, TypeError, NameError, Errno::ENOENT, ArgumentError, Errno::EACCES => exp

  ensure
    render :json => result
  end

  def upload_sequence

    @fatal_error = catch(:error) {
      # save file as session[:p_alignment]

      if params[:is_example]
        @basename = "coronin.fas"
        f_src = "#{Rails.root}/public/sample/#{@basename}"

        Helper.move_or_copy_file(f_src, session[:p_alignment], 'copy')

        @seq_names = SequenceHelper.read_in_alignment(session[:p_alignment])

      else
        file = params[:file]
        @basename = file.original_filename

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE) 

        # store file in place
        Helper.move_or_copy_file(file.tempfile, session[:p_alignment], "move")

        # call fromdos 
        is_sucess = system("fromdos", session[:p_alignment])

        # read in data
        @seq_names = SequenceHelper.read_in_alignment(session[:p_alignment])

        throw :error, 'Cannot upload file. Please contact us.' if ! is_sucess
      end

      "" # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = exp.message

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT, Errno::EACCES, ArgumentError => exp
      @fatal_error = 'Cannot upload file. Please contact us.'

    ensure
      render :upload_sequence, formats: [:js]
  end

  def upload_gene_structures
    @fatal_error = catch(:error) {

      @is_example = params[:is_example]

      if @is_example
        genes = Dir["#{Rails.root}/public/sample/gene_structures/*"]

        genes.each do |gene|
          Helper.move_or_copy_file(gene, session[:p_gene_structures], 'copy')
        end

        @gene_names = genes.collect! do |gene|
          File.basename(gene, ".yaml")
        end

      else
        file = params[:files][0]

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)
        Helper.move_or_copy_file(file.path(), session[:p_gene_structures], 'move')

        # rename to original name
        Helper.rename(File.join(session[:p_gene_structures], File.basename(file.path())),
          File.join(session[:p_gene_structures], file.original_filename))

        @filename = file.original_filename

        # call fromdos
        is_sucess = system('fromdos', File.join(session[:p_gene_structures], file.original_filename))
        throw :error, 'Cannot upload files. Please contact us.' if ! is_sucess
      end

      "" # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = exp.message

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT, Errno::EACCES, ArgumentError => exp
      @fatal_error = 'Cannot upload files. Please contact us.'

    ensure
      respond_to do |format|
        format.js
      end
  end

  def upload_species_mapping
    @fatal_error = catch(:error) {

      @is_example = params[:is_example]

      if @is_example
        @basename = "fastaheaders2species.txt"
        path = "#{Rails.root}/public/sample/#{@basename}"
        Helper.move_or_copy_file(path, session[:basepath_data], 'copy')

      else
        file = params[:files][0]
        path = file.path()

        @basename = file.original_filename

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

        tmp_file = File.open(path, "rb").read
        File.open("#{session[:basepath_data]}/fastaheaders2species.txt", "a") { |f|
          f.write(tmp_file)
        }

        # call fromdos
        is_sucess = system('fromdos', "#{session[:basepath_data]}/fastaheaders2species.txt")
        throw :error, 'Cannot upload file. Please contact us.' if ! is_sucess
      end

      [] # default for @fatal_error
    }
  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError, TypeError => ex
    @fatal_error = 'Cannot load file. Please contact us.'
  ensure
      map_sequence_name_to_species

      respond_to do |format|
        format.js
      end
  end

  def upload_pdb

    @fatal_error = catch(:error) {
      # save file as session[:p_pdb]

      if params[:is_example]
        @basename = "2AQ5.pdb"
        f_src = "#{Rails.root}/public/sample/#{@basename}"

        Helper.move_or_copy_file(f_src, session[:p_pdb], 'copy')

      else
        file = params[:file]
        @basename = file.original_filename

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE) 

        # store file in place
        Helper.move_or_copy_file(file.tempfile, session[:p_pdb], "move")

        # call fromdos 
        is_sucess = system("fromdos", session[:p_pdb])

        throw :error, 'Cannot upload file. Please contact us.' if ! is_sucess
      end

      "" # default for @fatal_error
    }

  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError, TypeError => ex
    @fatal_error = 'Cannot load file. Please contact us.'
  ensure
      respond_to do |format|
        format.js
      end

  end

  def update_species_mapping
    @task = params[:task]

    logger.debug(@task)

    if @task == "insert"
      @new_mapping = params[:new_mapping]
      species = params[:species] == nil ? "" : params[:species]

      # if find a species
      @error_message = nil
      if Node.any_of(scientific_name: "#{species}").length > 0
        File.open("#{session[:basepath_data]}/fastaheaders2species.txt", "a") { |f|
          f.write("#{@new_mapping}\n")
        }
      else
        @error_message = "Species not found."
      end
    else

      @updated_mapping = params[:data]

    end

  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    @fatal_error = 'Cannot update species mapping.'
  ensure
    respond_to do |format|
      format.js
    end
  end

  def create_alignment_file
    sequence_string = params[:sequence]
    @fatal_error = ""

    FormatChecker.validate_fasta(sequence_string)

    # Use default filename
    if File.exist?(session[:p_alignment])
      f = File.open(session[:p_alignment], 'w+')
    else
      f = File.new(session[:p_alignment], 'w+')
    end

    if File.writable?(f)
      f.write(sequence_string)
    end
    f.close

    @seq_names = SequenceHelper.read_in_alignment(session[:p_alignment])

  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    @fatal_error = 'Error parsing sequence alignment'
  ensure
    render :upload_sequence, formats: [:js]
  end

  def map_sequence_name_to_species
    session[:genes_to_species_map] = SequenceHelper.map_genenames_to_speciesnames(session[:basepath_data] + '/fastaheaders2species.txt')
  end

  def call_genepainter
    @fatal_error = "" # fatal, not output generated
    @warning = "" # non-fatal error, maybe still output generated

    @is_example = params[:is_example]
    missing_gene_structures = params[:data] == nil ? [] : params[:data]

    # build taxonomy lists
    all_species = params[:all_species] == nil ? [] : params[:all_species]
    taxonomy_list = ""

    if all_species.length > 0
      all_species.each do |s|

        if Node.any_of({ scientific_name: "#{s}"}).length > 0

          species = Node.any_of({ scientific_name: "#{s}"}).first

          lineage = []
          current_taxon = species
          while not current_taxon.root?
            lineage << current_taxon
            current_taxon = current_taxon.parent
          end
          lineage  << current_taxon

          path = lineage.map do |node|
            node.scientific_name
          end

          taxonomy_list << path.reverse.join(";") << "\n"
        end
      end
    end

    filename = "taxonomy_list.csv"

    File.open("#{session[:basepath_data]}/#{filename}", "w") { |file|
      file.write(taxonomy_list)
    }

    # regenerate fastaheaders2species.txt file with data from data center
    new_mapping_str = params[:new_mapping] == nil ? "" : params[:new_mapping]
    if new_mapping_str.length > 0
      # delete old file
      File.delete("#{session[:basepath_data]}/fastaheaders2species.txt")
      # write to a new one
      File.open("#{session[:basepath_data]}/fastaheaders2species.txt", "w") { |file|
        file.write(new_mapping_str)
      }
    end

    # apply data selection for analysis
    selected_genes = params[:analyse] == nil ? [] : params[:analyse] 
    d_gene_structures = File.join(session[:basepath_data], 'selected_gene_structures')
    Helper.mkdir_or_die(d_gene_structures)

    all_genes = Dir[ File.join( session[:p_gene_structures], "*" ) ]
    all_genes.each do |f_src|
      f_src_basename = File.basename(f_src, ".*")
      if @is_example || selected_genes.include?( f_src_basename ) then 
        Helper.move_or_copy_file(f_src, d_gene_structures, 'copy')
      end
    end

    # do NOT use session[:p_gene_structures], as this contains _all_ genestructures
    # use d_gene_structures instead, which contains _selected_ genestructures only
    f_alignment = session[:p_alignment]
    d_output = "#{Rails.root}/public/tmp"
    f_species_to_fasta = Dir[session[:basepath_data] + '/fastaheaders2species.txt'].first
    f_pdb = session[:p_pdb]
    f_taxonomy_list = "#{session[:basepath_data]}/taxonomy_list.csv"

    Helper.mkdir_or_die(d_output)

    # Prefix to all output files
    prefix = session[:id]

    # Creates missing gene structures
    # generate gene structures only for those genes that are part of the analysis
    missing_gene_structures = missing_gene_structures & selected_genes
    if !missing_gene_structures.blank?
      @warning = catch(:error) do 
        is_sucess, new_gene_structures = GenestructureHelper.generate_gene_structures(
          missing_gene_structures, f_species_to_fasta, f_alignment, d_gene_structures
        )
        if is_sucess then 
          session[:new_gene_structures] = new_gene_structures
        else
          throw :error, "Could not generated requested gene structures."
        end
        "" # default error-message
      end
    end

    # re-check if there are gene structures at all
    # (this is neccessary, as there might have been no upload at all, but just request to generate them - which might have failed)
    if Helper.is_dir_empty(d_gene_structures) then 
      Helper.raise_runtime_error "Cannot execute GenePainter. No gene structures found."
    end

    # call genepainter
    options_io = "-i #{f_alignment} -p #{d_gene_structures} --outfile #{prefix} --path-to-output #{d_output}"
    options_text_output = "--intron-phase --phylo --spaces --alignment --statistics"
    options_graphical_output = "--svg --svg-format both --svg-merged --svg-nested"
    options_taxonomic_output = "--intron-numbers-per-taxon --taxonomy-to-fasta #{f_species_to_fasta} --tree --taxonomy #{f_taxonomy_list}"
    options_pdb_output = "--pdb #{f_pdb} --consensus 0.8"

    is_sucess = nil
    # the default options for gene painter call
    all_options = "#{options_io} #{options_text_output} #{options_graphical_output}"

    if ! f_species_to_fasta.blank?
      # add options for tax. output
      all_options += " #{options_taxonomic_output}"
    end

    if Helper.does_file_exist(f_pdb) then 
      # add options for pdb output
      all_options += " #{options_pdb_output}"
    end

    # Call gene_painter
    is_sucess = system "ruby #{F_gene_painter} #{all_options}"

    if is_sucess then 
      is_output_written = Helper.does_file_exist( File.join(d_output, "#{prefix}-std.txt") )
      if ! is_output_written then 
        # stand-alone genepainter failed
        Helper.raise_runtime_error "Cannot execute GenePainter."
      end
    else
      # stand-alone genepainter failed
      Helper.raise_runtime_error "Cannot execute GenePainter."
    end

    genes_to_show = Dir["#{d_gene_structures}/*.yaml"].take(20)
    genes_to_show.map! do |gene|
      File.basename(gene, '.yaml')
    end

    SvgParser.build_svg_by_genestructs(build_output_path("normal.svg"),
        build_output_path("genenames-normal.svg"),
        build_output_path("genestructures-normal.svg"),
        build_output_path("legend-normal.svg"),
        genes_to_show)

    SvgParser.build_svg_by_genestructs(build_output_path("normal-merged.svg"),
        build_output_path("genenames-normal-merged.svg"),
        build_output_path("genestructures-normal-merged.svg"),
        build_output_path("legend-normal-merged.svg"),
        ["Merged"])

    SvgParser.build_svg_by_genestructs(build_output_path("reduced.svg"),
        build_output_path("genenames-reduced.svg"),
        build_output_path("genestructures-reduced.svg"),
        build_output_path("legend-reduced.svg"),
        genes_to_show)

    SvgParser.build_svg_by_genestructs(build_output_path("reduced-merged.svg"),
        build_output_path("genenames-reduced-merged.svg"),
        build_output_path("genestructures-reduced-merged.svg"),
        build_output_path("legend-reduced-merged.svg"),
        ["Merged"])


  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError, TypeError => ex
    @fatal_error = "Cannot execute GenePainter."
  ensure
    respond_to do |format|
      format.js
    end
  end

  def build_svg
    @error = ""
    genes_to_show = params[:data] == nil ? [] : params[:data]

    # Create images for selected genes only
    SvgParser.build_svg_by_genestructs(build_output_path("normal.svg"),
        build_output_path("genenames-normal.svg"),
        build_output_path("genestructures-normal.svg"),
        build_output_path("legend-normal.svg"),
        genes_to_show)

    SvgParser.build_svg_by_genestructs(build_output_path("reduced.svg"),
        build_output_path("genenames-reduced.svg"),
        build_output_path("genestructures-reduced.svg"),
        build_output_path("legend-reduced.svg"),
        genes_to_show)

  rescue RuntimeError => ex
    @error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError, TypeError => ex
    @error = "Cannot show selected genes."
  ensure
    respond_to do |format|
      format.js
    end
  end

  def download_new_genestructs
    @error = ""
    p_src_all = File.join(session[:basepath_data], 'selected_gene_structures')
    p_src_only_new = File.join(session[:basepath_data], 'newly_gen_gene_structures')
    Helper.mkdir_or_die(p_src_only_new)

    session[:new_gene_structures].each do |f_name|
      f_path_src = File.join(p_src_all, f_name)
      f_path_dest = File.join(p_src_only_new, f_name)
      Helper.move_or_copy_file(f_path_src, f_path_dest, "copy")
    end

    p_dest = build_output_path("genestucts.zip")
    Helper.zip_folder_or_die(p_src_only_new, p_dest)

    send_file p_dest, :x_sendfile => true

  rescue RuntimeError, NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    @error = "Cannot prepare gene structures for download."
  ensure 
    render plain: 'Cannot prepare gene structures for download'
  end

  def download_resultfiles
    f_path = build_output_path( params[:file] )
    send_file f_path, :x_sendfile => true
  end

  def build_output_path(filename)
    return "#{Rails.root}/public/tmp/#{session[:id]}-#{filename}"
  end

  def clean_up
    files_to_remove = Dir["#{Rails.root}/public/tmp/#{session[:id]}*"]

    if files_to_remove.blank?
    else
      files_to_remove.each do |file|
        File.delete(file)
      end
    end
  rescue RuntimeError, NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
  end

end
