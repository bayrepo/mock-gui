require "inifile"

class IniConfig
  attr :path

  def initialize(in_path = "config.ini")
    @path = in_path
    @config = {}
    parse_ini
  end

  def parse_ini()
    return if path.nil?
    return unless File.exist? path
    @config = IniFile.load(path)
  end

  def get_port()
    unless @config["server"]["port"].nil?
      @config["server"]["port"].to_i
    else
      8080
    end
  end

  def get_repo()
    unless @config["repo"]["repo"].nil?
      @config["repo"]["repo"].to_s
    else
      "repo"
    end
  end

  def get_db()
    unless @config["server"]["db"].nil?
      @config["server"]["db"].to_s
    else
      "db"
    end
  end

  def get_configs_hide()
    unless @config["configs"]["hide"].nil?
      @config["configs"]["hide"].split(",").map { |item| item.strip }
    else
      []
    end
  end

  def get_configs_selected()
    unless @config["configs"]["selected"].nil?
      @config["configs"]["selected"].split(",").map { |item| item.strip }
    else
      []
    end
  end

  def get_projects_path()
    unless @config["projects"]["path"].nil?
      @config["projects"]["path"].to_s
    else
      "projects"
    end
  end

  def get_counter_path()
    unless @config["counter"]["path"].nil?
      @config["counter"]["path"].to_s
    else
      "locks/counter"
    end
  end

  def get_items_per_page()
    unless @config["pages"]["items_per_page"].nil?
      res = @config["pages"]["items_per_page"].to_i
      if res < 1
        res = 30
      end
      res
    else
      30
    end
  end

  def get_keys_path()
    unless @config["sign"]["path"].nil?
      @config["sign"]["path"].to_s
    else
      "keys"
    end
  end

  def get_repoview_path()
    unless @config["repoview"]["path"].nil?
      @config["repoview"]["path"].to_s
    else
      "repoview"
    end
  end
end
