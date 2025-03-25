$LOAD_PATH.unshift File.expand_path(".", "locallibs/ruby-rpm-ffi/lib")

require "rpm"

require_relative "runner"
require "ptools"
require "fileutils"
require "erb"

class RPMReader
  def get_rpm_info(path_to_rpm)
    res = { :error => nil }
    if File.exist?(path_to_rpm)
      pkg = RPM::Package.open(path_to_rpm)
      res[:pkginfo] = pkg
    else
      res[:error] = "#{path_to_rpm} не существует"
    end
    res
  end
end

class RepoManagerKeys
  attr :path, :error

  def initialize(path)
    @error = nil
    @path = path
  end

  def check_key_exists()
    key_file = File.join(@path, "public", "mockgui-gpg-key")
    File.exist?(key_file)
  end

  def check_password_exists()
    passwd = nil
    passwd_file = File.join(@path, "save")
    if File.exist?(passwd_file)
      unless File.binary?(passwd_file)
        passwd = File.readlines(passwd_file).first.strip
      end
    end
    passwd
  end

  def get_publick_key()
    File.join(@path, "public", "mockgui-gpg-key")
  end

  def sign_package(rpm_path, password)
    cmd_args = %Q(/usr/bin/rpm --define "_gpg_sign_cmd_extra_args --pinentry-mode loopback --passphrase #{password}" --addsign "#{rpm_path}" 2>/dev/null)
    cmd = Runner.new(cmd_args)
    cmd.run
    cmd.exit_status
  end
end

class RepoManager
  attr :path, :error, :last_status, :last_pid

  def initialize(path)
    @error = nil
    unless File.exist? (path)
      Dir.mkdir(path)
    end
    @path = path
    @reader = RPMReader.new
  end

  def create_repo
    repo_path = File.join(@path, "repodata")
    cmd_args = %Q(/usr/bin/createrepo_c --database --workers 1 "#{@path}")
    if File.exist?(repo_path)
      cmd_args = %Q(/usr/bin/createrepo_c --database --workers 1 --update "#{@path}")
    end
    cmd = Runner.new(cmd_args)
    cmd.run
    @last_status = cmd.exit_status
    @last_pid = cmd.pid
  end

  def get_rpm_info(path_to_rpm)
    @reader.get_rpm_info(path_to_rpm)
  end

  def repoview(url, repo_name, template_dir)
    rpm_list = get_rpms_list(@path)
    result = {}
    rpm_list.each do |item|
      full_rpm_path = File.join(@path, item)
      info = @reader.get_rpm_info(full_rpm_path)
      dirName = File.dirname(item)
      fileName = File.basename(item)
      if result[dirName].nil?
        result[dirName] = []
      end
      pkg_info = {}
      pkg_info[:fname] = fileName
      pkg_info[:aname] = item
      pkg_info[:stat] = File.stat(full_rpm_path).ctime
      if info[:error].nil?
        pkg_info[:chlog] = info[:pkginfo].changelog.first(5)
      else
        pkg_info[:chlog] = []
      end
      result[dirName] << pkg_info
    end
    repo_name = repo_name
    repo_url = url
    pkg_num = rpm_list.length
    repo_data = []
    data_keys = []
    result.each_pair do |key, value|
      result[key.to_s].sort_by! { |item| item[:fname] }
      data_keys << key.to_s
    end
    data_keys.sort!
    data_keys.each do |item|
      repo_data << [result[item], item]
    end
    tpl_file = File.join(template_dir, "template.erb")
    template = File.read(tpl_file)
    renderer = ERB.new(template)
    result_html = renderer.result(binding)

    boots_trap_css = File.join(template_dir, "bootstrap.min.css")
    boots_trap_js = File.join(template_dir, "bootstrap.bundle.min.js")
    index_html = File.join(@path, "index.html")
    File.open(index_html, "w") do |f|
      f.write(result_html)
    end
    FileUtils.cp_r(boots_trap_css, @path, verbose: false, remove_destination: true)
    FileUtils.cp_r(boots_trap_js, @path, verbose: false, remove_destination: true)
  end
end
