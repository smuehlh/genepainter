# create tmpdir if neccessary
# dir-mode is host-depended
if ! Helper.does_dir_exist(TMP_PATH) then 
	if ENV && ENV["PWD"] && ENV["PWD"].include?("fab8") then 
		FileUtils.mkdir(TMP_PATH, :mode => 0775)
	else
		FileUtils.mkdir(TMP_PATH, :mode => 0755)
	end
end
