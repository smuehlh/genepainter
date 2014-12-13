class GenePainterController < ApplicationController

  @@gene_structure_to_status_map = {} # use class variable as hot-fix for issue that first uploaded gene structure not stored otherwise
  def id
    session[:id]
  end

  def p_gene_structures
    session[:p_gene_structures]
  end

  def sequence_names
    session[:sequence_names]
  end

  def genes_to_species_map
    session[:genes_to_species_map]
  end

  def new_gene_structures
    session[:new_gene_structures]
  end

  def gene_structure_to_status_map
    @@gene_structure_to_status_map
  end

  # prepare a new session 
  def prepare_new_session
    reset_session
    session[:id] = "" # id used as folder and file names
    session[:basepath_data] = "" # path to folder containing input data 
    session[:p_alignment] = "" # path to file containing input alignment
    session[:p_gene_structures] = "" # path to folder containing gene structures
    session[:sequence_names] = [] # list of fasta headers
    session[:genes_to_species_map] = {} # hash with genes and corresponding species
    session[:p_pdb] = "" # path to PDB file
    session[:new_gene_structures] = [] # newly generated gene structures
    @@gene_structure_to_status_map = {} # hash with genes (that have a gene structure) and the status of that gene structures
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

  # generate species list for species to fasta mapping
  def autocomplete
    list = Autocomplete.search( params[:q] )
    # convert to array of hashes to satisfy jquery ui autocomplete plugin
    list = list.map do |species|
      { value: species.scientific_name }
    end

  rescue RuntimeError, NoMethodError, TypeError, NameError, Errno::ENOENT, ArgumentError, Errno::EACCES => exp
  ensure
    render json: list
  end

  def upload_sequence

    @fatal_error = catch(:error) {
      # save file as session[:p_alignment]

      if params[:is_example]
        @basename = "coronin.fas"
        f_src = "#{Rails.root}/public/sample/#{@basename}"

        Helper.move_or_copy_file(f_src, session[:p_alignment], 'copy')

        @seq_names = SequenceHelper.read_in_alignment(session[:p_alignment])
        session[:sequence_names] = @seq_names

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
        session[:sequence_names] = @seq_names

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
        pathes_to_genes = Dir["#{Rails.root}/public/sample/gene_structures/*"]

        pathes_to_genes.each do |path|
          gene = File.basename(path, ".*")

          Helper.move_or_copy_file(path, session[:p_gene_structures], 'copy')
          @@gene_structure_to_status_map[gene] = GenestructureHelper.get_status_of_gene_structure(path)
          # session[:gene_structure_to_status_map][gene] = GenestructureHelper.get_status_of_gene_structure(path)
        end
      else

        file = params[:files][0]

        # validate file

        FormatChecker.validate_genestructure( file.path, file.original_filename )

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)
        Helper.move_or_copy_file(file.path(), session[:p_gene_structures], 'move')

        # rename to original name
        path_src = File.join( session[:p_gene_structures], File.basename(file.path()) )
        path_dest = File.join(session[:p_gene_structures], file.original_filename)
        Helper.rename(path_src, path_dest)

        # call fromdos
        is_sucess = system('fromdos', File.join(session[:p_gene_structures], file.original_filename))
        throw :error, 'Cannot upload files. Please contact us.' if ! is_sucess


        # save gene structure and status 
        gene = File.basename(path_dest, ".*")    
        @@gene_structure_to_status_map[gene] = GenestructureHelper.get_status_of_gene_structure(path_dest) 
      end

      "" # default for @fatal_error
    }

    @n_gene_structs = @@gene_structure_to_status_map.size

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

    @is_example = params[:is_example]

    if @is_example
      @basename = "fastaheaders2species.txt"
      path = "#{Rails.root}/public/sample/#{@basename}"
      Helper.move_or_copy_file(path, session[:basepath_data], 'copy')

    else
      file = params[:files][0]
      path = file.path()

      @basename = file.original_filename

      # validate file
      FormatChecker.validate_speciesmapping(path)

      # check file size
      Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

      Helper.move_or_copy_file(path, "#{session[:basepath_data]}/fastaheaders2species.txt", 'copy')

      # call fromdos
      is_sucess = system('fromdos', "#{session[:basepath_data]}/fastaheaders2species.txt")
      Helper.raise_runtime_error 'Cannot upload file. Please contact us.' if ! is_sucess
    end
    map_sequence_name_to_species

  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError, TypeError => ex
    @fatal_error = 'Cannot load file. Please contact us.'
  ensure
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

        # validate file
        FormatChecker.validate_pdb(file.path, @basename)

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
 
    @fatal_error = catch(:error) do 
      if params[:task] == "insert" then 
        # add new species-names pair

        if ! params.has_key?("species") ||
          params["species"].blank? then 
          throw :error, "No species selected."
        end
   
        if ! params.has_key?("names") ||
          params["names"].empty? then 
          throw :error, "No genes are selected."
        end

        # no error occured, so gene-species pair can be saved
        # key: gene, value: species
        params["names"].each do |name|
          session[:genes_to_species_map][name] = params["species"]
        end     

      elsif params[:task] == "delete"
        # delete a species-names pair

        if ! params.has_key?("names") ||
          params["names"].empty? then 
          throw :error, "No genes are selected."
        end

        # no error occured, delete gene-species pair
        params["names"].each do |name|
          session[:genes_to_species_map].delete(name)
        end
      end
      "" # default error-message
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
    session[:sequence_names] = @seq_names

  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    @fatal_error = 'Error parsing sequence alignment'
  ensure
    render :upload_sequence, formats: [:js]
  end

  def map_sequence_name_to_species
    session[:genes_to_species_map] = SequenceHelper.map_genenames_to_speciesnames(
      session[:basepath_data] + '/fastaheaders2species.txt'
    )
  end

  def call_genepainter

    @fatal_error = "" # fatal, not output generated
    @warning = "" # non-fatal error, maybe still output generated

    # do NOT use session[:p_gene_structures], as this contains _all_ genestructures
    # use d_gene_structures instead, which contains _selected_ genestructures only
    f_alignment = session[:p_alignment]
    d_output = "#{Rails.root}/public/tmp"
    f_species_to_fasta = File.join(session[:basepath_data], 'fastaheaders2species.txt')
    f_pdb = session[:p_pdb]
    f_taxonomy_list = File.join(session[:basepath_data], 'taxonomy_list.csv')

    Helper.mkdir_or_die(d_output)


    @is_example = params[:is_example] == "true" # params is string "true" or string "false"
    missing_gene_structures = params[:generate_genestruct] == nil ? [] : params[:generate_genestruct]
    all_species = params[:species] == nil ? [] : params[:species]
    all_species = all_species.reject{|e| e.empty?} # delete empty strings (no species info given)
    selected_genes = params[:analyse] == nil ? [] : params[:analyse] 


    # build taxonomy lists and write gene to species mapping, not if example
    if @is_example then
      # example data
      # copy taxonomy list and species mapping to data folder
      d_sample = File.join("#{Rails.root}", "public", "sample")
      f_src = File.join( d_sample, "taxonomy_list.csv" )
      Helper.move_or_copy_file(f_src, f_taxonomy_list, "copy")

      f_src = File.join( d_sample, "fastaheaders2species.txt" )
      Helper.move_or_copy_file(f_src, f_species_to_fasta, "copy")

    else
     
      # no example data, build tax. list
      taxonomy_list = ""

      all_species.each do |provided_species|

        if found_species = Node.any_of( { scientific_name: provided_species} , { common_names: provided_species } ).first then 

          lineage = []
          current_taxon = found_species
          while not current_taxon.root?
            lineage << current_taxon
            current_taxon = current_taxon.parent
          end
          lineage  << current_taxon

          path = lineage.map do |node|
            node.scientific_name
          end

          # change species name to user-provided one
          # this is neccessary for gene painter to establish connection
          if path[0] != provided_species then 
            path[0] = provided_species
          end

          taxonomy_list << path.reverse.join(";") << "\n"
        end
      end

      File.open(f_taxonomy_list, "w") { |file|
        file.write(taxonomy_list)
      }

      # write gene to species-mapping to file
      fh = File.open(f_species_to_fasta, "w")
      session[:genes_to_species_map].each do |gene, species|
        fh.puts "#{gene}:\"#{species}\""
      end
      fh.close

    end 

    # apply data selection for analysis, in case of example: use all genes
    d_gene_structures = File.join(session[:basepath_data], 'selected_gene_structures')
    Helper.mkdir_or_die(d_gene_structures)

    all_genes = Dir[ File.join( session[:p_gene_structures], "*" ) ]
    all_genes.each do |f_src|
      f_src_basename = File.basename(f_src, ".*")
      if @is_example || selected_genes.include?( f_src_basename ) then 
        Helper.move_or_copy_file(f_src, d_gene_structures, 'copy')
      end
    end

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
          new_gene_structures.each do |gene|
            matching_files = Dir.glob( File.join(d_gene_structures, gene, ".*") )
            if path = matching_files[0] then 
              @@gene_structure_to_status_map[gene] = GenestructureHelper.get_status_of_gene_structure(path) 
            end
          end
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

    if session[:genes_to_species_map].any? then 
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

    genes_to_show = session[:sequence_names]

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

  # def build_svg
  #   @error = ""
  #   genes_to_show = params[:data] == nil ? [] : params[:data]

  #   # Create images for selected genes only
  #   SvgParser.build_svg_by_genestructs(build_output_path("normal.svg"),
  #       build_output_path("genenames-normal.svg"),
  #       build_output_path("genestructures-normal.svg"),
  #       build_output_path("legend-normal.svg"),
  #       genes_to_show)

  #   SvgParser.build_svg_by_genestructs(build_output_path("reduced.svg"),
  #       build_output_path("genenames-reduced.svg"),
  #       build_output_path("genestructures-reduced.svg"),
  #       build_output_path("legend-reduced.svg"),
  #       genes_to_show)

  # rescue RuntimeError => ex
  #   @error = ex.message
  # rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError, TypeError => ex
  #   @error = "Cannot show selected genes."
  # ensure
  #   respond_to do |format|
  #     format.js
  #   end
  # end

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
    render plain: 'Cannot prepare gene structures for download'
  end

  def download_resultfiles
    f_path = build_output_path( params[:file] )
    send_file f_path, :x_sendfile => true

  rescue RuntimeError, NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    render plain: "Cannot prepare file \"#{params[:file]}\" for download"
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
