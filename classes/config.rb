require "inifile"

# Класс для работы с конфигурацией INI-файла
class IniConfig
  attr :path

  # Конструктор класса, принимает путь к INI-файлу и парсит его содержимое
  def initialize(in_path = "config.ini")
    @path = in_path
    @config = {}
    parse_ini
  end

  # Метод для парсинга INI-файла и загрузки его содержимого в хэш
  def parse_ini()
    return if path.nil?
    return unless File.exist? path
    @config = IniFile.load(path)
  end

  # Метод для получения порта сервера из конфигурации, если он задан, иначе возвращает значение по умолчанию (8080)
  def get_port()
    unless @config["server"]["port"].nil?
      @config["server"]["port"].to_i
    else
      8080
    end
  end

  # Метод для получения репозитория из конфигурации, если он задан, иначе возвращает значение по умолчанию ("repo")
  def get_repo()
    unless @config["repo"]["repo"].nil?
      @config["repo"]["repo"].to_s
    else
      "repo"
    end
  end

  # Метод для получения базы данных из конфигурации, если она задана, иначе возвращает значение по умолчанию ("db")
  def get_db()
    unless @config["server"]["db"].nil?
      @config["server"]["db"].to_s
    else
      "db"
    end
  end

  # Метод для получения скрытых конфигураций из конфигурации, если они заданы, иначе возвращает пустой массив
  def get_configs_hide()
    unless @config["configs"]["hide"].nil?
      @config["configs"]["hide"].split(",").map { |item| item.strip }
    else
      []
    end
  end

  # Метод для получения выбранных конфигураций из конфигурации, если они заданы, иначе возвращает пустой массив
  def get_configs_selected()
    unless @config["configs"]["selected"].nil?
      @config["configs"]["selected"].split(",").map { |item| item.strip }
    else
      []
    end
  end

  # Метод для получения пути к проектам из конфигурации, если он задан, иначе возвращает значение по умолчанию ("projects")
  def get_projects_path()
    unless @config["projects"]["path"].nil?
      @config["projects"]["path"].to_s
    else
      "projects"
    end
  end

  # Метод для получения пути к счетчику из конфигурации, если он задан, иначе возвращает значение по умолчанию ("locks/counter")
  def get_counter_path()
    unless @config["counter"]["path"].nil?
      @config["counter"]["path"].to_s
    else
      "locks/counter"
    end
  end

  # Метод для получения пути к блокировке сборки из конфигурации, если он задан, иначе возвращает значение по умолчанию ("locks/build")
    def get_build_lock_path()
    unless @config["build"]["path"].nil?
      @config["build"]["path"].to_s
    else
      "locks/build"
    end
  end

  # Метод для получения количества элементов на странице из конфигурации, если оно задано и больше нуля, иначе возвращает значение по умолчанию (30)
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

  # Метод для получения пути к ключам из конфигурации, если он задан, иначе возвращает значение по умолчанию ("keys")
  def get_keys_path()
    unless @config["sign"]["path"].nil?
      @config["sign"]["path"].to_s
    else
      "keys"
    end
  end

  # Метод для получения пути к реповьюверу из конфигурации, если он задан, иначе возвращает значение по умолчанию ("repoview")
  def get_repoview_path()
    unless @config["repoview"]["path"].nil?
      @config["repoview"]["path"].to_s
    else
      "repoview"
    end
  end
end
