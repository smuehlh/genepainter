require 'parse_data.rb'
require 'genestructures.rb'
require 'parse_svg.rb'
require 'helper.rb'

class GenePainterController < ApplicationController

  @@id = ''
  @@f_dest = '' # Helper.make_new_tmp_dir(TMP_PATH)
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

    clean_up

    # Generate a dir in tmp to store uploaded files
    id = Helper.make_new_tmp_dir(TMP_PATH)

    @@f_dest = File.join(TMP_PATH, id)
    @@default_fname = File.join(@@f_dest, 'alignment')
    @@f_gene_structures = File.join(@@f_dest, 'gene_structures')

    @@id = @@f_dest.split('/').last

    Helper.mkdir_or_die(@@f_gene_structures)

    expires_now()
  end

  def get_species
    q = params[:q] == nil ? "" : params[:q]
    result = {}

    result["data"] = Node.all_of(scientific_name: /^#{q}/i).map do |node|
      node.scientific_name
    end
  rescue RuntimeError, NoMethodError, TypeError, NameError, Errno::ENOENT => exp

  ensure
    render :json => result
  end

  def upload_sequence
    @fatal_error = catch(:error) {

      if params[:is_example]
        @basename = "coro_sel.fas"
        path = "#{Rails.root}/public/sample/#{@basename}"

        Helper.mkdir_or_die(@@f_dest)
        Helper.move_or_copy_file(path, @@f_dest, 'copy')

        @seq_names = read_in_alignment(path)[0]

      else
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
        throw :error, 'Cannot upload file. Please contact us.' if ! is_sucess
      end

      "" # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = exp.message

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
      @fatal_error = 'Cannot upload file. Please contact us.'

    ensure
      @@seq_names = @seq_names
      render :upload_sequence, formats: [:js]
  end

  def upload_gene_structures
    @fatal_error = catch(:error) {

      @is_example = params[:is_example]

      if @is_example
        genes = Dir["#{Rails.root}/public/sample/gene_structures/*"]

        genes.each do |gene|
          Helper.move_or_copy_file(gene, @@f_gene_structures, 'copy')
        end

        @gene_names = genes.collect! do |gene|
          File.basename(gene, ".yaml")
        end

      else
        file = params[:files][0]

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)
        Helper.move_or_copy_file(file.path(), @@f_gene_structures, 'move')

        # rename to original name
        Helper.rename(File.join(@@f_gene_structures, File.basename(file.path())),
          File.join(@@f_gene_structures, file.original_filename))

        @filename = file.original_filename

        # call fromdos
        is_sucess = system('fromdos',@@f_dest)
        throw :error, 'Cannot upload files. Please contact us.' if ! is_sucess
      end

      "" # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = exp.message

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
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
        Helper.move_or_copy_file(path, @@f_dest, 'copy')

      else
        file = params[:files][0]
        path = file.path()

        @basename = file.original_filename

        # check file size
        Helper.filesize_below_limit(file.tempfile, MAX_FILESIZE)

        tmp_file = File.open(path, "rb").read
        File.open("#{@@f_dest}/fastaheaders2species.txt", "a") { |f|
          f.write(tmp_file)
        }

        # call fromdos
        is_sucess = system('fromdos',@@f_dest)
        throw :error, 'Cannot upload file. Please contact us.' if ! is_sucess
      end

      [] # default for @fatal_error
    }

    rescue RuntimeError => exp
      @fatal_error = exp.message

    rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
      @fatal_error = 'Cannot load file. Please contact us.'

    ensure
      map_sequence_name_to_species

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
        File.open("#{@@f_dest}/fastaheaders2species.txt", "a") { |f|
          f.write("#{@new_mapping}\n")
        }
      else
        @error_message = "Species not found."
      end
    else

      @updated_mapping = params[:data]

    end
  rescue RuntimeError => exp
    @error_message = exp.message

  rescue NoMethodError, TypeError, NameError, Errno::ENOENT => exp
    @error_message = 'Cannot update species mapping.'

  ensure
    respond_to do |format|
      format.js
    end
  end

  def create_alignment_file
    sequence_string = params[:sequence]
    @errors = ""

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
    @errors = 'Error parsing sequence alignment'
  rescue RuntimeError, Errno::ENOENT, NameError => ex
    @errors = ex.message
  ensure
    respond_to do |format|
      format.js
    end
  end

  def map_sequence_name_to_species
    @@name_species_map = map_genenames_to_speciesnames(@@f_dest + '/fastaheaders2species.txt')
  end


# TODO
# check return values of system calls
# if false: render error! 
  def create_gene_structures
    @errors = ""
    @is_example = params[:is_example]
    missing_gene_structures = params[:data] == nil ? [] : params[:data]

    # build taxonomy lists
    all_species = params[:all_species] == nil ? [] : params[:all_species]
    taxonomy_list = ""

    if all_species.length > 0
      all_species.each do |s|

        if Node.any_of({ scientific_name: "#{s}"}).length > 0

          species = Node.any_of({ scientific_name: "#{s}"}).first
          # logger.debug("species test: #{species.inspect}")

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

    File.open("#{@@f_dest}/#{filename}", "w") { |file|
      file.write(taxonomy_list)
    }

    # regenerate fastaheaders2species.txt file with data from data center
    new_mapping_str = params[:new_mapping] == nil ? "" : params[:new_mapping]
    if new_mapping_str.length > 0
      # delete old file
      File.delete("#{@@f_dest}/fastaheaders2species.txt")
      # write to a new one
      File.open("#{@@f_dest}/fastaheaders2species.txt", "w") { |file|
        file.write(new_mapping_str)
      }
    end

    f_alignment = Dir[@@f_dest + '/*.fas'].first
    d_gene_structures = File.join(@@f_dest, 'gene_structures')
    d_output = "#{Rails.root}/public/tmp"
    f_species_to_fasta = Dir[@@f_dest + '/fastaheaders2species.txt'].first
    f_taxonomy_list = "#{@@f_dest}/taxonomy_list.csv"

    Helper.mkdir_or_die(d_output)

    # Prefix to all output files
    prefix = @@id

    # Creates missing gene structures
    if !missing_gene_structures.blank?
      @retVal, @new_genes = generate_gene_structures(missing_gene_structures, f_species_to_fasta, f_alignment, d_gene_structures)
logger.debug("*********")
      logger.debug(@retVal)
      logger.debug(@new_genes.inspect)
    else
      @new_genes = []
    end

    if f_species_to_fasta.blank?
      logger.debug("Didn't find any fastaheaders2species files.")

      # Call gene_painter
      @retVal = system "ruby #{F_gene_painter} -i #{f_alignment} -p #{d_gene_structures} --outfile #{prefix} --path-to-output #{d_output} --intron-phase --phylo --spaces --alignment --svg --svg-format both --svg-merged --svg-nested --statistics"
    else
      @retVal = system "ruby #{F_gene_painter} -i #{f_alignment} -p #{d_gene_structures} --outfile #{prefix} --path-to-output #{d_output} --intron-phase --phylo --spaces --alignment --svg --svg-format both --svg-merged --svg-nested --statistics --intron-numbers-per-taxon --taxonomy-to-fasta #{f_species_to_fasta} --tree --taxonomy #{f_taxonomy_list}"
    end
logger.debug("***********")
logger.debug @retVal
    genes_to_show = Dir["#{d_gene_structures}/*.yaml"].take(20)
    genes_to_show.map! do |gene|
      File.basename(gene, '.yaml')
    end

    logger.debug(genes_to_show.inspect)
    logger.debug("Return from sys call: " + @retVal.to_s)

    build_svg_by_genestructs(build_output_path("normal.svg"),
        build_output_path("genenames-normal.svg"),
        build_output_path("genestructures-normal.svg"),
        build_output_path("legend-normal.svg"),
        genes_to_show)

    build_svg_by_genestructs(build_output_path("normal-merged.svg"),
        build_output_path("genenames-normal-merged.svg"),
        build_output_path("genestructures-normal-merged.svg"),
        build_output_path("legend-normal-merged.svg"),
        ["Merged"])

    build_svg_by_genestructs(build_output_path("reduced.svg"),
        build_output_path("genenames-reduced.svg"),
        build_output_path("genestructures-reduced.svg"),
        build_output_path("legend-reduced.svg"),
        genes_to_show)

    build_svg_by_genestructs(build_output_path("reduced-merged.svg"),
        build_output_path("genenames-reduced-merged.svg"),
        build_output_path("genestructures-reduced-merged.svg"),
        build_output_path("legend-reduced-merged.svg"),
        ["Merged"])
  rescue  NoMethodError => ex
    @errors = 'Error parsing sequence alignment'
  rescue RuntimeError, Errno::ENOENT, NameError => ex
    @errors = ex.message
  ensure
    respond_to do |format|
      format.js
    end
  end

  def build_svg
    genes_to_show = params[:data] == nil ? [] : params[:data]

    # Create images for selected genes only
    build_svg_by_genestructs(build_output_path("normal.svg"),
        build_output_path("genenames-normal.svg"),
        build_output_path("genestructures-normal.svg"),
        build_output_path("legend-normal.svg"),
        genes_to_show)

    build_svg_by_genestructs(build_output_path("reduced.svg"),
        build_output_path("genenames-reduced.svg"),
        build_output_path("genestructures-reduced.svg"),
        build_output_path("legend-reduced.svg"),
        genes_to_show)

  end

  def build_output_path(filename)
    return "#{Rails.root}/public/tmp/#{@@id}-#{filename}"
  end

  def clean_up
    files_to_remove = Dir["#{Rails.root}/public/tmp/#{@@id}*"]

    if files_to_remove.blank?
    else
      files_to_remove.each do |file|
        File.delete(file)
      end
    end
    rescue  NoMethodError => ex
      @errors = 'Error cleaning up old data'
    rescue RuntimeError, Errno::ENOENT, NameError => ex
      @errors = ex.message
  end

end
