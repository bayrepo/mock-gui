# Подключаем файл utilities.rb для использования его методов
require_relative "utilities"

# Класс ConfigsList для работы со списком конфигураций
class ConfigsList
  # Определение свойств класса
  attr :error, :cfg

  # Конструктор класса с параметром cfg
  def initialize(cfg)
    @cfg = cfg
  end

  # Метод get_configs для получения списка конфигураций
  def get_configs
    # Получаем список скрытых конфигураций из cfg
    hide_list = @cfg.get_configs_hide
    # Получаем список выбранных конфигураций из cfg
    select_list = @cfg.get_configs_selected

    # Создаем список глобальных конфигураций в директории /etc/mock/*.cfg
    list_global = Dir["/etc/mock/*.cfg"].map { |item| [File.dirname(item), File.basename(item, ".cfg"), item] }.reject { |item| check_partname_in_array(item[1], hide_list) }

    # Проверяем наличие глобальных конфигураций и создаем пустой список, если их нет
    if list_global.nil?
      list_global = []
    end

    # Создаем список локальных конфигураций в директории ~/.config/mock/*.cfg
    list_local = Dir["~/.config/mock/*.cfg"].map { |item| [File.dirname(item), File.basename(item, ".cfg"), item] }

    # Проверяем наличие локальных конфигураций и создаем пустой список, если их нет
    if list_local.nil?
      list_local = []
    end

    # Создаем список выбранных конфигураций из глобального и локального списка
    list_selected = (list_global + list_local).select { |item| check_partname_in_array(item[1], select_list) }

    # Проверяем наличие выбранных конфигураций и создаем пустой список, если их нет
    if list_selected.nil?
      list_selected = []
    end

    # Возвращаем хеш с глобальными, локальными и выбранными конфигурациями
    { :global => list_global, :local => list_local, :selected => list_selected }
  end

end
