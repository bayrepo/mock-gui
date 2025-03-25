require_relative "utilities"

class ConfigsList
  attr :error, :cfg

  def initialize(cfg)
    @cfg = cfg
  end

  def get_configs
    hide_list = @cfg.get_configs_hide
    select_list = @cfg.get_configs_selected
    list_global = Dir["/etc/mock/*.cfg"].map { |item| [File.dirname(item), File.basename(item, ".cfg"), item] }.reject { |item| check_partname_in_array(item[1], hide_list) }
    if list_global.nil?
      list_global = []
    end
    list_local = Dir["~/.config/mock/*.cfg"].map { |item| [File.dirname(item), File.basename(item, ".cfg"), item] }
    if list_local.nil?
      list_local = []
    end
    list_selected = (list_global + list_local).select { |item| check_partname_in_array(item[1], select_list) }
    if list_selected.nil?
      list_selected = []
    end
    { :global => list_global, :local => list_local, :selected => list_selected }
  end
end
