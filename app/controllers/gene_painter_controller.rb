class GenePainterController < ApplicationController

  protect_from_forgery except: :clean_up

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
    session[:gene_structure_to_status_map]
  end

  def p_alignment
    session[:p_alignment]
  end

  def p_species_mapping
    session[:p_species_mapping]
  end

  def is_pdb 
    Helper.does_file_exist( session[:p_pdb] )
  end

  def pdb_chains
    session[:pdb_chains]
  end

  def p_pdb
    session[:p_pdb]
  end

  # prepare a new session 
  def prepare_new_session

    session[:id] = "" # id used as folder and file names
    session[:basepath_data] = "" # path to folder containing input data 
    session[:p_alignment] = "" # path to file containing input alignment
    session[:p_gene_structures] = "" # path to folder containing gene structures
    session[:p_species_mapping] = ""
    session[:sequence_names] = [] # list of fasta headers
    session[:genes_to_species_map] = {} # hash with genes and corresponding species
    session[:p_pdb] = "" # path to PDB file
    session[:pdb_chains] = [] # chains found in pdb file
    session[:new_gene_structures] = [] # newly generated gene structures
    session[:gene_structure_to_status_map] = {} # hash with genes (that have a gene structure) and the status of that gene structures
    session[:basepath_output] = "" # path to folder containing output data

    # Generate a dir in tmp to store uploaded files
    session[:id] = Helper.make_new_tmp_dir(TMP_PATH)

    session[:basepath_data] = File.join(TMP_PATH, session[:id])
    session[:p_alignment] = File.join(session[:basepath_data], 'input.fas')
    session[:p_gene_structures] = File.join(session[:basepath_data], 'gene_structures')
    session[:p_species_mapping] = File.join(session[:basepath_data], 'fastaheaders2species.txt')
    session[:p_pdb] = File.join(session[:basepath_data], 'pdb.pdb')
    session[:basepath_output] = File.join(Rails.root, "public", "tmp", session[:id])

    Helper.mkdir_or_die(session[:p_gene_structures])

  end

  # Render start page for GenePainter
  def gene_painter
# do not reset_session since this causes Invalid CSRF tokens when using multiple sessions     
#     reset_session
    
    prepare_new_session

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
    rescue Moped::Errors::ConnectionFailure
      list = []
    ensure 
      render json: list
  end

  def upload_sequence
    @is_fileupload = true
    @is_example = params[:is_example]
    @fatal_error = catch(:error) {
      # save file as session[:p_alignment]

      if @is_example then 
        if params[:sample_data] == "coronin" then 
          @basename = "coronin.fas"
        elsif params[:sample_data] == "tubulin"
          @basename = "tubulin.fas"
        end
        f_src = File.join(Rails.root, "public", "sample", params[:sample_data], @basename)

        Helper.move_or_copy_file(f_src, session[:p_alignment], 'copy')

        @seq_names, dummy = SequenceHelper.read_in_alignment(session[:p_alignment])
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
        @seq_names, dummy = SequenceHelper.read_in_alignment(session[:p_alignment])
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
        pathes_to_genes = Dir[ File.join(Rails.root, "public", "sample", params[:sample_data], "gene_structures", "*") ]
        pathes_to_genes.each do |path|
          gene = File.basename(path, ".*")

          Helper.move_or_copy_file(path, session[:p_gene_structures], 'copy')
          session[:gene_structure_to_status_map][gene] = GenestructureHelper.get_status_of_gene_structure(path)
        end
      else

        params[:files].each do |file|
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
          session[:gene_structure_to_status_map][gene] = GenestructureHelper.get_status_of_gene_structure(path_dest) 
        end

      end

      "" # default for @fatal_error
    }

    @n_gene_structs = session[:gene_structure_to_status_map].size

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
      path = File.join(Rails.root, "public", "sample", params[:sample_data], @basename)
      Helper.move_or_copy_file(path, session[:p_species_mapping], 'copy')

    else
      file = params[:files][0]
      path = file.path()

      @basename = file.original_filename

      # validate file
      FormatChecker.validate_speciesmapping(path)

      # check file size
      Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

      Helper.move_or_copy_file(path, session[:p_species_mapping], 'copy')

      # call fromdos
      is_sucess = system('fromdos', session[:p_species_mapping])
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

    @is_example = params[:is_example]

    @fatal_error = catch(:error) {
      # save file as session[:p_pdb]

      if @is_example then 
        @basename = ""
        if params[:sample_data] == "coronin" then 
          @basename = "2AQ5.pdb"
        else
          @basename = "1TUB.pdb"
        end
        f_src = File.join(Rails.root, "public", "sample", params[:sample_data], @basename)

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

      session[:pdb_chains] = PdbParser.get_chains(session[:p_pdb])

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
    @is_fileupload = false

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

    @seq_names, dummy = SequenceHelper.read_in_alignment(session[:p_alignment])
    session[:sequence_names] = @seq_names

  rescue RuntimeError => ex
    @fatal_error = ex.message
  rescue NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    @fatal_error = 'Error parsing sequence alignment'
  ensure
    render :upload_sequence, formats: [:js]
  end

  def map_sequence_name_to_species
    session[:genes_to_species_map] = SequenceHelper.map_genenames_to_speciesnames( session[:p_species_mapping] )
  end

  def call_genepainter

    @fatal_error = "" # fatal, not output generated
    @warning = "" # non-fatal error, maybe still output generated
    is_skipped_taxonomy = false

    # do NOT use session[:p_gene_structures], as this contains _all_ genestructures
    # use d_gene_structures instead, which contains _selected_ genestructures only
    f_alignment = session[:p_alignment]
    d_output = session[:basepath_output]
    f_species_to_fasta = File.join(session[:basepath_data], 'fastaheaders2species.txt')
    f_pdb = session[:p_pdb]
    f_taxonomy_list = File.join(session[:basepath_data], 'taxonomy_list.csv')

    Helper.mkdir_or_die(d_output)

    @is_example = params[:is_example] == "true" # params is string "true" or string "false"
    missing_gene_structures = params[:generate_genestruct] == nil ? [] : params[:generate_genestruct]

    selected_genes = params[:analyse] == nil ? [] : params[:analyse] 

    # all species belonging to genes selected for analysis
    all_species = session[:genes_to_species_map].collect {|k,v| v if selected_genes.include?(k)}
    all_species = all_species.compact.uniq # might contain nil values and duplicated values

    # build taxonomy lists and write gene to species mapping, not if example
    if @is_example then
      # example data
      # copy taxonomy list and species mapping to data folder
      d_sample = File.join("#{Rails.root}", "public", "sample", params[:sample_data])
      f_src = File.join( d_sample, "taxonomy_list.csv" )
      Helper.move_or_copy_file(f_src, f_taxonomy_list, "copy")

      f_src = File.join( d_sample, "fastaheaders2species.txt" )
      Helper.move_or_copy_file(f_src, f_species_to_fasta, "copy")

    else
      begin   
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
      rescue Moped::Errors::ConnectionFailure
        # mongo db error, call GenePainter without taxonomy
        is_skipped_taxonomy = true
        @warning = "Could not fetch taxonomy. Called GenePainter without taxonomy."
      end
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
    prefix = "results" # same prefix used in build_output_files method

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
              session[:gene_structure_to_status_map][gene] = GenestructureHelper.get_status_of_gene_structure(path) 
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
    options_text_output = "--intron-phase --alignment --statistics --fuzzy #{params[:fuzzy_val]}"
    options_graphical_output = "--svg --svg-format both --svg-merged --svg-nested"

    is_sucess = nil
    # the default options for gene painter call
    all_options = "#{options_io} #{options_text_output} #{options_graphical_output}"

    if ! is_skipped_taxonomy && all_species.any? then 
      # add options for tax. output
      # as taxonomy was generated and at least some selected genes have species mapping!
      options_taxonomic_output = "--intron-numbers-per-taxon --taxonomy-to-fasta #{f_species_to_fasta} --tree --taxonomy #{f_taxonomy_list}"

      all_options += " #{options_taxonomic_output}"
    end

    if is_pdb then 

      # add options for pdb output
      ref_seq = params[:pdb_ref_seq] || session[:sequence_names][0]
      ref_seq = SequenceHelper.speciesname_to_fastaheader(ref_seq)
      chain = params[:pdb_chain] || session[:pdb_chains]
      options_pdb_output = "--pdb #{f_pdb} --pdb-chain #{chain} --pdb-ref-prot \"#{ref_seq}\""
      if params[:pdb_use] == "merged" then 
        options_pdb_output += " --merge"
      elsif params[:pdb_use] == "consensus"
        consensus_val = params[:pdb_consensus_val].to_f / 100
        options_pdb_output += " --consensus #{consensus_val}"
      else
        options_pdb_output += " --pdb-ref-prot-struct"
      end       
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

  def display_genestruct
    @info = ""

    # find file, file-extension (is yaml or gff file?) is not known
    file = Dir.glob(File.join(p_gene_structures, "#{params[:gene]}.*") )[0]
    @content = view_context.render_file(file)

    rescue RuntimeError, NoMethodError, TypeError, NameError, Errno::EISDIR, Errno::ENOENT, Errno::EACCES, ArgumentError => exp
      @info = 'Cannot display file.'

    ensure
      render :display_genestruct, formats: [:js]
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
    render plain: 'Cannot prepare gene structures for download'
  end

  def download_resultfiles
    f_path = build_output_path( params[:file] )
    send_file f_path, :x_sendfile => true

  rescue RuntimeError, NoMethodError, Errno::ENOENT, Errno::EACCES, ArgumentError, NameError => ex
    render plain: "Cannot prepare file \"#{params[:file]}\" for download"
  end

  def build_output_path(filename)
    return File.join(session[:basepath_output], "results-#{filename}")
  end

  def clean_up
    FileUtils.remove_dir( session[:basepath_output] )

    clear_session

  rescue RuntimeError, NoMethodError, Errno::ENOENT, Errno::EACCES, Errno::ENOTEMPTY, ArgumentError, NameError => ex
  end

end
