class StaticPagesController < ApplicationController
  def home
  end

  def help
  end

  def download
  end
  def download_sources
    f_path = File.join("public", "downloads", params[:file])
    send_file f_path, :x_sendfile => true
  end

  def team
  end

  def contact
  end
end
