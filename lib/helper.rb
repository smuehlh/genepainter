module Helper
	extend self

	# general error handling methods
	def raise_runtime_error(msg="Fatal: An error occured")
		raise msg
	end

	def worked_or_die(is_success, msg)
		if ! is_success then
			raise_runtime_error "Fatal: #{msg}"
		end
	end

	def worked_or_throw_error(is_success, msg)
		if ! is_success then
			throw :problem, msg
		end
		is_success
	end

	# general file handling methods
	def file_exist_or_die(path)
		if ! FileTest.file?(path) then
			raise_runtime_error "Fatal: File #{path} does not exist."
		end
	end

	def does_file_exist(path)
		if ! FileTest.file?(path) then
			return false
		end
		true
	end

	def dir_exist_or_die(path)
		if ! FileTest.directory?(path) then
			raise_runtime_error "Fatal: Directory #{path} does not exist."
		end
	end

	def mkdir_or_die(path)
		if ! FileTest.directory?(path) then
			begin
				# Dir.mkdir(path)
				FileUtils.mkdir_p(path)
			rescue
				raise_runtime_error "Fatal: Cannot create directory #{path}"
			end
		end
	end

	def move_or_copy_file(f_scr,f_dest,operation)
		file_exist_or_die(f_scr)
		case operation
		when "copy"
			FileUtils.cp(f_scr, f_dest)
		when "move"
			FileUtils.mv(f_scr, f_dest)
		end
	rescue
		raise_runtime_error "Error during setup. Please contact us."
	end

	def chmod(f_dest, mode)
		File.chmod(mode, f_dest)
	rescue
		raise_runtime_error "Error during setup. Please contact us."
	end

	# expecting a [params] file
	def filesize_below_limit(file, max_size)
		if file.size > max_size then
			msg = []
			msg << "File must be less than #{(max_size/1024)/1024} MB"
			msg << "Please contact us to upload larger files."
			throw :error, msg
		end
		true
	end

  def rename(oldname, newname)
    File.rename(oldname, newname)
  end

	# load reference data from file alignment_gene_structure.json
	# @return [Hash] reference data
	# @return [Array] Errors occured during file load
	def load_ref_data
		path = File.join( ProteinFamily.class_variable_get(:@@ref_data_path), REF_DATA)
		file_exist_or_die(path)
		return JSON.load(File.read(path))
	end

	def provide_trna_ref_data_path
		path = File.join( BASE_PATH_TRNA, TRNA_REF_DATA)
		file_exist_or_die(path)
		return path
	end

	def get_tmp_file(extension="fasta")
		rand(1000000).to_s + "." + extension
	end

	def make_new_tmp_dir(base_path)
		id = rand(1000000000).to_s
		path = File.join(base_path, id)
		mkdir_or_die(path)
		return id
	end

	# remove all files from specified path
	# exept files with file_basename allowed_filebasename
	def clean_up_tmp_dir(base_path, allowed_files)
		Dir.glob(File.join(base_path, "*")) do |file|
			if allowed_files.include?(file) then
				next
			end
			if FileTest.file?(file) then
				# delete only files, no directories
				File.delete(file)
			end
		end
	end

end
