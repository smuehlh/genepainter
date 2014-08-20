TMP_PATH = File.join(Dir::tmpdir, "gene_painter/")
MAX_FILESIZE = 52428800 # 50MB

#host depending settings
if ENV && ENV["PWD"] && ENV["PWD"].include?("fab8") then
    Lucullus_url = "http://fab8:8080/tpl_os"
	F_gene_painter = '/fab8/server/db_scripts/gene_painter_new/gene_painter/gene_painter.rb'
else
    Lucullus_url = "http://www.motorprotein.de/tpl_os"
end