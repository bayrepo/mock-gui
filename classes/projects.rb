require "fileutils"
require_relative "db"
require_relative "repomanage"
require_relative "mock"
require_relative "utilities"
require "digest"

PROJECTS_STRUCTURE = {
  :REPO => "repo",
  :LOGS => "logs",
  :CONFIGS => "configs",
  :SRCPRP => "srcprp",
  :SIGNED => "signed",
  :SRC => "src",
  :SNAP => "snapshot",
}

class ProjectsActions
  attr :path, :error, :db

  def initialize(path, db)
    @path = nil
    @error = nil
    @db = db
    if File.absolute_path?(path)
      if File.exist?(path)
        @path = path
      end
    else
      apath = File.realpath(path)
      if File.exist?(apath)
        @path = apath
      end
    end
  end

  def get_projects
    @db.proj_list
  end

  def get_project(id)
    @db.proj(id.to_i)
  end

  def get_project_path(id)
    @error = nil
    fname = nil
    prj = @db.proj(id)
    if prj.nil?
      @error = "Проекта с id = #{id} не существует"
    else
      fname = File.expand_path("#{prj[:projname]}.prj", @path)
    end
    fname
  end

  def get_project_config(id)
    @error = nil
    fname = nil
    prj = @db.proj(id)
    if prj.nil?
      @error = "Проекта с id = #{id} не существует"
    else
      fname = File.expand_path("#{prj[:projname]}.prj", @path)
      fname = File.join(fname, PROJECTS_STRUCTURE[:CONFIGS], "#{prj[:projname]}.cfg")
    end
    fname
  end

  def get_project_repo(id)
    proj_path = get_project_path(id)
    File.join(proj_path, PROJECTS_STRUCTURE[:REPO])
  end

  def get_project_snap(id, snap)
    proj_path = get_project_path(id)
    File.join(proj_path, PROJECTS_STRUCTURE[:SNAP], snap)
  end

  def get_project_path_git(id, gitname)
    proj_path = get_project_path(id)
    File.join(proj_path, PROJECTS_STRUCTURE[:SRC], gitname)
  end

  def generate_linked_repos(id, proj_path, proj_name, linked_repo_tpl)
    linked_prj = []
    proj_repo_path = File.join(proj_path, PROJECTS_STRUCTURE[:REPO])
    proj_repo = <<~PRJ_CFG
      config_opts['dnf.conf'] += """
      [#{proj_name}-repository]
      name=Project repository #{proj_name}
      baseurl=file://#{proj_repo_path}
      enabled=1
      priority=80
      skip_if_unavailable=True
      """
    PRJ_CFG
    linked_prj << proj_repo
    unless id.nil?
      link_prj_list = @db.get_projects_links(id)
      unless link_prj_list.nil?
        link_prj_list.each do |item|
          internal_repo = ProjectsActions.new(@path, @db)
          internal_path = internal_repo.get_project_path(item[:proj_id_repository])
          internal_repo_path = File.join(internal_path, PROJECTS_STRUCTURE[:REPO])
          internal_proj_info = internal_repo.get_project(item[:proj_id_repository])
          proj_repo = <<~PRJ_CFG
            config_opts['dnf.conf'] += """
            [#{internal_proj_info[:projname]}-repository]
            name=Project repository #{internal_proj_info[:projname]}
            baseurl=file://#{internal_repo_path}
            enabled=1
            skip_if_unavailable=True
            """
          PRJ_CFG
          linked_prj << proj_repo
        end
      end
    end
    File.open(linked_repo_tpl, "w") { |f| f << linked_prj.join("\n\n\n") }
  end

  def regenerate_linked_repos(id)
    proj_path = get_project_path(id)
    config_path = File.join(proj_path, PROJECTS_STRUCTURE[:CONFIGS])
    prj_incl_path = File.join(config_path, "repos_include.tpl")
    prj_info = get_project(id)
    unless prj_info.nil?
      generate_linked_repos(id, proj_path, prj_info[:projname], prj_incl_path)
    end
  end

  def generate_config(id, configuration_path, proj_path, proj_name)
    proj_conf_path = File.join(proj_path, PROJECTS_STRUCTURE[:CONFIGS], "#{proj_name}.cfg")
    conf_path = File.join(proj_path, PROJECTS_STRUCTURE[:CONFIGS])
    prj_incl_path = File.join(conf_path, "repos_include.tpl")
    proj_config = <<~PRJ_CFG
      include("#{configuration_path}")
      include("#{prj_incl_path}")
      config_opts['plugin_conf']['ccache_enable'] = False
      config_opts['plugin_conf']['ccache_opts']['max_cache_size'] = '4G'
      config_opts['plugin_conf']['ccache_opts']['hashdir'] = True
      config_opts['plugin_conf']['ccache_opts']['debug'] = False
      config_opts['plugin_conf']['ccache_opts']['show_stats'] = True
      config_opts['plugin_conf']['package_state_enable'] = True
      config_opts['plugin_conf']['procenv_enable'] = False
      config_opts['plugin_conf']['root_cache_enable'] = True
      config_opts['plugin_conf']['showrc_enable'] = True
      config_opts['plugin_conf']['yum_cache_enable'] = True
      config_opts['chroot_setup_cmd'] += " gcc gcc-c++ make"
    PRJ_CFG
    File.open(proj_conf_path, "w") { |f| f << proj_config }
    generate_linked_repos(id, proj_path, proj_name, prj_incl_path)
  end

  def create_project(name, description, configuration, nopublic, tmpbld)
    @error = nil
    ret_val = 0
    project_name = sanitize_rcptname(name)
    fname = File.expand_path("#{project_name}.prj", @path)
    if File.exist?(fname)
      @error = "Проект с таким именем уже существует: #{project_name}"
      ret_val = 1
    else
      created = false
      #begin
      Dir.mkdir(fname)
      PROJECTS_STRUCTURE.each_pair do |key, value|
        new_path = File.join(fname, value)
        Dir.mkdir(new_path)
      end
      if File.exist?(configuration)
        generate_config(nil, configuration, fname, project_name)
        @error = @db.proj_create(project_name, description, nopublic, tmpbld)
        if @error.nil?
          created = true
        end
        repo_path = File.join(fname, PROJECTS_STRUCTURE[:REPO])
        repoman = RepoManager.new(repo_path)
        repoman.create_repo
      else
        ret_val = 1
        @error = "Конфигурация #{configuration} не существует"
      end
      #rescue => e
      #  ret_val = 1
      #  @error = e.message
      #end
      unless created
        FileUtils.rm_rf(fname, secure: true)
      end
    end
    ret_val
  end

  def get_project_gits(id, repo)
    res = @db.get_gits_for_projects(id)
    res_sync = res.map do |item|
      prj_p = get_project_path(id)
      path = File.join(prj_p, PROJECTS_STRUCTURE[:SRC], item[:reponame])
      item[:is_repo_synced] = repo.is_repos_sync(item[:reponame], path)
      item
    end
    res
  end

  def add_git_to_project(prj_id, git_id, repo, git_name)
    path = get_project_path(prj_id)
    if @error.nil?
      path = File.join(path, PROJECTS_STRUCTURE[:SRC], git_name)
      err = repo.clone_repo_master(git_id, path)
      if err.nil?
        @db.save_git_project(prj_id, git_id)
      end
    else
      err = @error
    end
    err
  end

  def renew_git_to_project(prj_id, git_id, repo, git_name)
    path = get_project_path(prj_id)
    if @error.nil?
      path = File.join(path, PROJECTS_STRUCTURE[:SRC], git_name)
      err = repo.clone_repo_master(git_id, path)
    else
      err = @error
    end
    err
  end

  def get_related_projects_list(prj_id)
    links_list = []
    links = @db.get_projects_links(prj_id)
    unless links.nil?
      links_list = links.map do |item|
        prj_info = @db.proj(item[:proj_id_repository])
        if prj_info.nil?
          item[:list_state] = false
        else
          item[:list_state] = true
          item[:prj_info] = prj_info
        end
        item
      end.select { |item| item[:list_state] }
    end
    links_list
  end

  def delete_linked_projects(prj_id)
    @db.delete_linked_projects(prj_id)
  end

  def save_linked_projects(prj_id, new_ids, delete_ids)
    delete_ids.each { |item| @db.delete_linked_projects_with_id(prj_id, item) }
    new_ids.each do |item|
      @db.save_linked_projects(prj_id, item)
    end
  end

  def find_spec_file(prj_id, git_id)
    spec_file = ""
    proj_path = get_project_path(prj_id)
    git_name = @db.get_repo_info_by_id(git_id)
    git_source = File.join(proj_path, PROJECTS_STRUCTURE[:SRC], git_name[:reponame])
    spec = @db.get_project_repo_spec(prj_id, git_id)
    if spec.nil?
      spec_files = get_spec_files_in_dir(git_source)
      unless spec_files.nil?
        spec_file = spec_files.first
      end
    else
      spec_file = spec[:spec_name]
    end
    spec_file
  end

  def build_projects_git(prj_id, git_id, counter_file, build_lock)
    bld_id = 0
    build_ok = true
    proj_path = get_project_path(prj_id)
    git_name = @db.get_repo_info_by_id(git_id)
    prep_script = @db.get_git_recips(git_id)
    prepare_path = File.join(proj_path, PROJECTS_STRUCTURE[:SRCPRP], git_name[:reponame])
    spec_file = find_spec_file(prj_id, git_id)
    repo_lock = File.join(proj_path, PROJECTS_STRUCTURE[:CONFIGS], ".repolock")
    if File.exist?(prepare_path)
      lockf_path = File.join(prepare_path, "lock")
      File.open(lockf_path, File::RDWR | File::CREAT) do |f|
        result = f.flock(File::LOCK_EX | File::LOCK_NB)
        if result == false
          # Файл заблокирован считать id и вывести сведения о сборке
          build_ok = false
          build_id = f.gets
          build_id = build_id.strip.to_i unless build_id.nil?
          if build_id.positive?
            build_info = @db.get_build_task_process_log(build_id)
            bld_id = build_info[:id] unless build_info.nil?
          end
        else
          # Сборка завершилась, но каталог не подчистился
          FileUtils.rm_rf(prepare_path)
          f.flock(File::LOCK_UN)
          build_ok = true
        end
      end
    end

    #Верная ситуация
    if build_ok
      build_path = File.join(proj_path, PROJECTS_STRUCTURE[:LOGS], git_name[:reponame])
      Dir.mkdir(prepare_path)
      lockf_path = File.join(prepare_path, "lock")
      File.open(lockf_path, File::RDWR | File::CREAT) do |f|
        f.flock(File::LOCK_EX)
        f.rewind
        #Начинаем сборку      
        @db.create_build_task(prj_id, git_id, build_path)
        build_id = @db.last_id    
        repo_path = File.join(proj_path, PROJECTS_STRUCTURE[:REPO])
        git_source = File.join(proj_path, PROJECTS_STRUCTURE[:SRC], git_name[:reponame])
        f.puts(build_id)
        f.flush
        proj_info = get_project(prj_id)
        tmp_bld = false
        tmp_bld = true if proj_info[:tmpstpbuild].to_i != 0
        mock = MockManager.new(prepare_path, get_project_config(prj_id), counter_file, @db, build_path, repo_path, git_source, build_id, prep_script, spec_file, repo_lock, git_id, tmp_bld)
        bld_id = build_id
        @db.update_build_task_error_log(build_id, mock.get_build_process_log)
        @db.update_build_task_status(build_id, 3)
        mock.build_task(build_lock)
      end
    end
    bld_id
  end

  def delete_git_from_project(prj_id, git_id)
    @error = nil
    builds_lst = db.get_builds_for_project_git(prj_id, git_id)
    active_build = false
    builds_lst.each do |item|
      if item[:state] == 0
        active_build = true
        break
      end
    end
    if active_build
      @error = "Нельзя удалить git репозиторий с незавершенными сборками"
    else
      proj_path = get_project_path(prj_id)
      git_name = @db.get_repo_info_by_id(git_id)
      git_source = File.join(proj_path, PROJECTS_STRUCTURE[:SRC], git_name[:reponame])
      FileUtils.rm_rf(git_source, secure: true)
      @db.delete_git_from_project(prj_id, git_id)
    end
    @error
  end

  def delete_project(prj_id)
    @error = nil
    builds_lst = db.get_builds_for_project(prj_id)
    active_build = false
    builds_lst.each do |item|
      if item[:state] == 0
        active_build = true
        break
      end
    end
    if active_build
      @error = "Нельзя удалить git репозиторий с незавершенными сборками"
    else
      linked = @db.projects_with_current_as_link(prj_id)
      if linked.nil? || linked.length == 0
        proj_path = get_project_path(prj_id)
        FileUtils.rm_rf(proj_path, secure: true)
        if @db.delete_project(prj_id) != 0 
          @error = "На текущий проект ссылаются другие проекты. Удаление запрещено"
        end
      else
        @error = "На текущий проект ссылаются другие проекты. Удаление запрещено"
      end
    end
    @error
  end

  def sign_project(prj_id, key_path, password, url, tpl_dir)
    @error = nil
    proj_path = get_project_path(prj_id)
    sign_repo_path = File.join(proj_path, PROJECTS_STRUCTURE[:SIGNED])
    repo_path = File.join(proj_path, PROJECTS_STRUCTURE[:REPO])
    repo_sign = RepoManager.new(sign_repo_path)
    repo_key = RepoManagerKeys.new(key_path)
    if password.nil?
      password = repo_key.check_password_exists
    end
    if password.nil?
      @error = "Не указан пароль для подписи"
    else
      repo_lock = File.join(proj_path, PROJECTS_STRUCTURE[:CONFIGS], ".repolock")
      sign_lock = File.join(proj_path, PROJECTS_STRUCTURE[:CONFIGS], ".signlock")
      prj = @db.proj(prj_id)
      if repo_key.check_key_exists
        File.open(sign_lock, File::RDWR | File::CREAT) do |s|
          s.flock(File::LOCK_EX)
          File.open(repo_lock, File::RDWR | File::CREAT) do |f|
            f.flock(File::LOCK_EX)
            rpm_list = get_rpms_list(repo_path)
            if prj[:public] == 0
              rpm_list = rpm_list.reject do |item|
                block = false
                block = true if item =~ /\.src\.rpm$/ || item =~ /SRPMS/ || item =~ /Debug/ || item =~ /(debuginfo.+rpm$)|(debugsource.+rpm$)/
                block
              end
            end
            rpm_signed_list = get_rpms_list(sign_repo_path)
            if rpm_signed_list.length > rpm_list.length 
              rpms_for_delete = get_rpms_list_full(sign_repo_path)
              rpms_for_delete.each do |item|
                File.unlink(item)
              end
            end
            rpm_list = rpm_list.select do |item|
              sign_repo_path_rpm = File.join(sign_repo_path, item)
              unless File.exist?(sign_repo_path_rpm)
                file_path_full = File.join(repo_path, item)
                unless File.exist?(File.dirname(sign_repo_path_rpm))
                  FileUtils.mkdir_p(File.dirname(sign_repo_path_rpm))
                end
                FileUtils.cp_r(file_path_full, File.dirname(sign_repo_path_rpm), verbose: false, remove_destination: false)
                sha256 = Digest::SHA256.file(file_path_full)
                rpm_info = @db.get_rpm_info_by_hash(sha256.hexdigest)
                unless rpm_info.nil?
                  @db.update_rpm_sign(rpm_info[:id], sign_repo_path_rpm)
                end
                repo_key.sign_package(sign_repo_path_rpm, password)
              end
            end
            repo_url = "http://localhost/"
            if prj[:remote_address].nil? || prj[:remote_address].strip == ""
              repo_url = url
            else
              repo_url = prj[:remote_address]
            end
            if repo_url[-1] != "/"
              repo_url = repo_url + "/"
            end
            repo_sign.repoview(repo_url, prj[:projname], tpl_dir)
            repo_sign.create_repo
            pub_key = repo_key.get_publick_key
            proj_repo_key = File.join(sign_repo_path, "#{prj[:projname]}-gpg-key")
            unless File.exist?(proj_repo_key)
              FileUtils.cp_r(pub_key, proj_repo_key, verbose: false, remove_destination: false)
            end
          end
        end
      else
        @error = "Ключ для подписи отсутствует"
      end
    end
    @error
  end

  def set_address(prj_id, address)
    @error = nil
    if address.nil?
      address = ""
    else
      address = address.strip
    end
    @db.set_project_address(prj_id, address)
    @error
  end

  def get_sign_path(id)
    path = get_project_path(id)
    File.join(path, PROJECTS_STRUCTURE[:SIGNED])
  end

  def recreate_repo(id)
    proj_path = get_project_path(id)
    repo_path = File.join(proj_path, PROJECTS_STRUCTURE[:REPO])
    repoman = RepoManager.new(repo_path)
    repoman.create_repo
  end

  def get_snap_list(id)
    proj_path = get_project_path(id)
    snap_path = File.join(proj_path, PROJECTS_STRUCTURE[:SNAP])
    
    unless Dir.exist?(snap_path)
      FileUtils.mkdir_p(snap_path)
    end

    snap_list = Dir.glob(File.join(snap_path, "*")).select { |path| File.directory?(path) }.map { |dir| File.basename(dir) }

    return snap_list
  end

  def create_snapshot(id)
    proj_path = get_project_path(id)
    snap_path = File.join(proj_path, PROJECTS_STRUCTURE[:SNAP])
    repo_path = File.join(proj_path, PROJECTS_STRUCTURE[:REPO])
    
    unless Dir.exist?(snap_path)
      FileUtils.mkdir_p(snap_path)
    end
    
    date_str = Time.now.strftime("%Y-%m-%d")
    snapshot_dir = "#{date_str}_0"

    while Dir.exist?(File.join(snap_path, snapshot_dir))
      num = snapshot_dir.split("_").last.to_i
      num += 1
      snapshot_dir = "#{date_str}_#{num}"
    end

    snapshot_full_path = File.join(snap_path, snapshot_dir)
    FileUtils.cp_r(repo_path, snapshot_full_path)
  end

  def delete_snapshot(id, snap)
    proj_path = get_project_path(id)
    snap_path = get_project_snap(id, snap)
    snap_path_base = File.join(proj_path, PROJECTS_STRUCTURE[:SNAP])
    unless snap_path == snap_path_base || "#{snap_path}/" == snap_path_base || snap_path == "#{snap_path_base}/"
      if File.exist?(snap_path)
        FileUtils.rm_rf(snap_path)
      end
    end
  end

  def restore_snapshot(id, snap)
    repo_path = get_project_repo(id)
    snap_path = get_project_snap(id, snap)
    
    if  Dir.exist?(repo_path) && Dir.exist?(snap_path)
      Dir.glob(File.join(repo_path, '*')).each { |file| File.unlink(file) if File.file?(file) || FileUtils.rm_rf(file) }
      FileUtils.cp_r(Dir.glob(File.join(snap_path, '*')), repo_path)
    end
  end
end
