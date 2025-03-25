require_relative "spork"
require_relative "runner"
require "fileutils"
require "logger"
require_relative "repomanage"
require "digest"

BUILD_STRUCTURE = {
  :SRC => "src",
  :RPMS => "rpms",
  :RESULT => "result",
  :RESULT_SRPM => "result_srpm",
}

class MockManager
  attr :path, :config, :error, :last_status, :last_pid, :prep_dir, :db, :resultpath, :process_log, :repo_path, :git_path, :build_id, :log, :recips, :spec, :repo_lock, :git_id

  def initialize(path, config, cfg_counter_path, db, result_path, repo_path, git_path, build_id, recips, spec_file, repo_lock, git_id)
    @error = nil
    unless File.exist? (path)
      Dir.mkdir(path)
    end
    @path = path
    @config = config
    cntr = 0
    @db = db
    @resultpath = result_path
    @repo_path = repo_path
    @git_path = git_path
    @build_id = build_id
    @recips = recips
    @spec = spec_file
    @repo_lock = repo_lock
    @git_id = git_id

    File.open(cfg_counter_path, "r+") do |f|
      f.flock(File::LOCK_EX)
      counter = f.gets.strip
      i_counter = counter.to_i
      i_counter = i_counter + 1
      f.puts("#{i_counter}")
      cnt = i_counter
    end
    tmp_name = (0...10).map { ("a".."z").to_a[rand(26)] }.join
    @prep_dir = File.join(path, "#{cntr}_#{tmp_name}")
    @process_log = File.join(@prep_dir, "process.log")
    Dir.mkdir(@prep_dir)
    FileUtils.touch(@process_log)
    @log = nil
    @tmp_src = ""
  end

  def get_build_process_log()
    @process_log
  end

  def clean_build
    FileUtils.rm_rf(@path)
  end

  def prepare_structure()
    @log.info("Подготовка структуры каталогов")
    BUILD_STRUCTURE.each_pair do |key, value|
      new_path = File.join(@prep_dir, value)
      @log.info("Создан каталог #{new_path}")
      Dir.mkdir(new_path)
    end
  end

  def prepare_src()
    @log.info("Подготовка исходных файлов проекта к формированию SRPMS")
    if File.exist?(@git_path)
      if File.directory?(@git_path)
        @tmp_src = File.join(@prep_dir, BUILD_STRUCTURE[:SRC], File.basename(@git_path))
        FileUtils.cp_r(@git_path, @tmp_src, verbose: true, remove_destination: true)
        FileUtils.rm_rf(File.join(@tmp_src, ".git"), secure: true)
      else
        @log.error("Это файл #{@git_path}, а не каталог")
        @error = true
      end
    else
      @log.error("Каталог #{@git_path} не существует")
      @error = true
    end
  end

  def prepare_source()
    @log.info("Запукс подготовительных скриптов")
    @recips.each_with_index do |item, index|
      @log.info("Формируем рецепт #{item[:filepath]}")
      rcp_name = "#{index}rcp_#{item[:filepath]}"
      File.open(File.join(@tmp_src, rcp_name), "w") do |f|
        f.write(item[:content].gsub(/\r$/, ""))
      end
      Dir.chdir(@tmp_src) do
        spec_file = File.join(@tmp_src, @spec)
        script = File.join(@tmp_src, rcp_name)
        cmd_args = %Q(/usr/bin/bash -x "#{script}" "#{spec_file}")
        @log.debug(cmd_args)
        cmd = Runner.new(cmd_args, @log)
        cmd.run_clean
        @error = true if cmd.exit_status != 0
        @log.error("Ошибка операции") if @error
      end
      break if @error
    end
  end

  def prepare_src_rpm()
    @log.info("Подготовка SRCRPM")
    spec_file = File.join(@tmp_src, @spec)
    if File.exist?(spec_file)
      Dir.chdir(@tmp_src) do
        cmd_args = %Q(/usr/bin/mock -r "#{@config}" --buildsrpm --spec "#{spec_file}" --sources "#{@tmp_src}" --resultdir "#{File.join(@prep_dir, BUILD_STRUCTURE[:RESULT_SRPM])}" --isolation=simple --disable-plugin=ccache)
        @log.debug(cmd_args)
        cmd = Runner.new(cmd_args, @log)
        cmd.run_clean
        @error = true if cmd.exit_status != 0
        @log.error("Ошибка операции") if @error
      end
    else
      @error = true
      @log.error("Не могу найти sepc файл #{spec_file}")
    end
  end

  def build_rpm()
    @log.info("Начало сборки пакетов")
    srpm_result_dir = File.join(@prep_dir, BUILD_STRUCTURE[:RESULT_SRPM])
    srpms = get_src_rpm_files_in_dir(srpm_result_dir)
    if srpms.nil? || srpms.length == 0
      @error = true
      @log.info("Нечего собирать, нет src.rpm пакетов")
    else
      srpm = srpms.first
      path_srpm = File.join(srpm_result_dir, srpm)
      cmd_args = %Q(/usr/bin/mock -r "#{@config}" "#{path_srpm}" --resultdir "#{File.join(@prep_dir, BUILD_STRUCTURE[:RESULT])}" --isolation simple)
      @log.debug(cmd_args)
      cmd = Runner.new(cmd_args, @log)
      cmd.run_clean
      @error = true if cmd.exit_status != 0
      @log.error("Ошибка операции") if @error
    end
  end

  def save_logs()
    FileUtils.mkdir_p(File.join(@resultpath, "#{@build_id}"))
    src_result = File.join(@prep_dir, BUILD_STRUCTURE[:RESULT_SRPM])
    rpm_result = File.join(@prep_dir, BUILD_STRUCTURE[:RESULT])
    if File.exist?(src_result)
      logs = get_log_paths(src_result)
      logs.each do |item|
        src = File.join(src_result, item)
        dst_dir = File.dirname(item)
        dst_fname = File.basename(item)
        dst = File.join(@resultpath, "#{@build_id}", dst_dir, "srpms_build_#{dst_fname}")
        FileUtils.cp_r(src, dst, verbose: true, remove_destination: true)
      end
    end
    if File.exist?(rpm_result)
      logs = get_log_paths(rpm_result)
      logs.each do |item|
        src = File.join(rpm_result, item)
        dst_dir = File.dirname(item)
        dst_fname = File.basename(item)
        dst = File.join(@resultpath, "#{@build_id}", dst_dir, "rpm_build_#{dst_fname}")
        FileUtils.cp_r(src, dst, verbose: true, remove_destination: true)
      end
    end
  end

  def save_rpms()
    @log.info("Формирование репозитория")
    repo = RepoManager.new(@repo_path)
    rpms = get_rpm_paths(File.join(@prep_dir, BUILD_STRUCTURE[:RESULT]))
    if rpms.nil? || rpms.length == 0
      @error = true
      @log.error("Пакеты не найдены")
    else
      prep_rpms = []
      rpms.each do |item|
        res = {}
        rpm_path = File.join(@prep_dir, BUILD_STRUCTURE[:RESULT], item)
        result = repo.get_rpm_info(rpm_path)
        if result[:error].nil?
          res[:src] = rpm_path
          res[:name] = result[:pkginfo].to_s
          arch = result[:pkginfo].arch
          if rpm_path =~ /\.src\.rpm$/
            res[:dst] = File.join(@repo_path, "SRPMS", File.basename(rpm_path))
          elsif rpm_path =~ /(debuginfo.+rpm$)|(debugsource.+rpm$)/
            res[:dst] = File.join(@repo_path, "Debug", File.basename(rpm_path))
          else
            if arch.nil? || arch.strip == ""
              arch = "noarch"
            end
            res[:dst] = File.join(@repo_path, arch, File.basename(rpm_path))
          end
          prep_rpms << res
        else
          @error = true
          @log.error("Ошибка пакета #{rpm_path}")
          break
        end
      end
      if @error == false
        File.open(@repo_lock, File::RDWR | File::CREAT) do |f|
          f.flock(File::LOCK_EX)
          # выклдака  пакетов и пересоздание repodata
          packages_uniq = true
          prep_rpms.each do |item|
            if File.exist?(item[:dst])
              packages_uniq = false
              break
            end
          end
          if packages_uniq
            prep_rpms.each do |item|
              @log.info("Копируется пакет #{item[:src]} в репозиторий #{item[:dst]}")
              FileUtils.mkdir_p(File.dirname(item[:dst]))
              FileUtils.cp_r(item[:src], item[:dst], verbose: true, remove_destination: true)
              sha256 = Digest::SHA256.file(item[:dst])
              @db.save_rpm(@build_id, item[:dst], item[:name], @git_id, sha256.hexdigest)
            end
            repo.create_repo
          else
            @error = true
            @log.error("Такие пакеты уже существуют в репозитории. Поднимите версию пакета")
          end
        end
      end
    end
  end

  def save_prg_log()
    FileUtils.mkdir_p(File.join(@resultpath, "#{@build_id}"))
    if File.exist?(@process_log)
      dst = File.join(@resultpath, "#{@build_id}")
      FileUtils.cp_r(@process_log, dst, verbose: false, remove_destination: true)
    end
  end

  def build_task()
    @error = false
    @db.before_fork
    spock = Spork.spork(:logger => log) do
      @db.after_fork
      old_stdout = $stdout.dup
      $stdout = File.open(@process_log, "w")
      @log = Logger.new($stdout)
      if @spec == ""
        @error = true
        @log.error("Не могу найти spec файл")
      end
      begin
        prepare_structure if @error == false
        prepare_src if @error == false
        prepare_source if @error == false
        prepare_src_rpm if @error == false
        build_rpm if @error == false
        save_logs
        save_rpms if @error == false
      rescue => e
        @error = true
        puts e
      end
      $stdout = old_stdout
      @log.close
      save_prg_log
      clean_build
      if @error
        @db.update_build_task_status(@build_id, 1)
      else
        @db.update_build_task_status(@build_id, 2)
      end
    end
    @db.after_fork
    spock
  end
end
