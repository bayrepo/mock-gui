require "socket"
require "etc"

def systeminfo_get_ip
  Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
end

def systeminfo_get_username
  Etc.getpwuid(Process.uid).name
end
