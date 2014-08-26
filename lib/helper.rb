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
		else
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

	def make_new_tmp_dir(base_path)
		id = rand(1000000000).to_s
		path = File.join(base_path, id)
		mkdir_or_die(path)
		return id
	end

	def zip_folder_or_die(p_scr, p_dest)
		is_success = system("zip -jr #{p_dest} #{p_scr}")
		worked_or_die(is_success, "Cannot compress folder #{p_scr}.")
	end

end
