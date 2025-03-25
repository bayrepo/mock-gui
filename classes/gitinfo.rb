require "rugged"
require "fileutils"
require_relative "db"

class GitRepo
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

  def create_git(project_name, description)
    @error = nil
    ret_val = 0
    fname = File.expand_path("#{project_name}.git", @path)
    if File.exist?(fname)
      @error = "Репозиторий с таким именем уже существует: #{project_name}"
      ret_val = 1
    else
      Dir.mkdir(fname)
      Rugged::Repository.init_at(fname, :bare)
      repo = Rugged::Repository.new(fname)
      created = false
      if repo.bare?
        @error = @db.creategit(project_name, description)
        if @error.nil?
          created = true
        end
      else
        @error = "Репозиторий почему-то не пустой"
      end
      unless created
        FileUtils.rm_rf(fname, secure: true)
      end
    end
    ret_val
  end

  def create_git_db_only(project_name)
    @error = @db.creategit(project_name, "")
    @error
  end

  def getrepos
    repos_data = []
    repos_files = Dir[File.join(@path, "*.git")]
    repos_files.each do |fl|
      repo_name = File.basename(fl, ".git")
      db_info = @db.get_repo_info_by_name(repo_name)
      unless db_info.nil?
        repos_data << { :reponame => db_info.reponame, :descr => db_info.descr, :public => db_info.public, :id => db_info.id }
      else
        result = create_git_db_only(repo_name)
        if result.nil?
          db_info = @db.get_repo_info_by_name(repo_name)
          repos_data << { :reponame => db_info.reponame, :descr => db_info.descr, :public => db_info.public, :id => db_info.id }
        end
      end
    end
    repos_data
  end

  def repo_info(reponame, branch = nil)
    info = {}
    result = ""
    @error = nil
    repos_data = { :full => 0 }
    git_path = File.join(@path, reponame + ".git")
    if File.exist?(git_path)
      repo = Rugged::Repository.new(git_path)
      db_info = @db.get_repo_info_by_name(reponame)
      unless db_info.nil?
        repos_data = { :reponame => db_info.reponame, :descr => db_info.descr, :public => db_info.public, :full => 1 }
      else
        result = create_git_db_only(reponame)
        if result.nil?
          db_info = @db.get_repo_info_by_name(reponame)
          db_info = db_info.first
          repos_data = { :reponame => db_info.reponame, :descr => db_info.descr, :public => db_info.public, :full => 1 }
        end
      end
      if repos_data[:full] == 1
        info[:info] = repos_data
        if repo.empty?
          info[:commits] = []
          info[:branches] = []
          info[:tags] = []
        else
          ref = repo.head
          unless branch.nil?
            ref_name = File.join("refs/heads/", branch)
            ref = repo.references[ref_name]
          end
          commits = []
          unless ref.nil?
            walker = Rugged::Walker.new(repo)
            walker.sorting(Rugged::SORT_DATE)
            walker.push(ref.target)
            commits = walker.map do |commit|
              { :message => commit.message, :author => commit.author, :time => commit.time, :sha => commit.oid }
            end.first(10)
          end
          info[:commits] = commits
          info[:branches] = repo.branches.each_name(:local).sort
          info[:tags] = repo.tags.map { |tag| tag.name }
        end
      else
        @error = result
      end
    else
      @error = "Репозиторий отсутсвует"
    end
    info[:error] = @error
    info
  end

  def delete_repo(reponame)
    git_path = File.expand_path(reponame + ".git", @path)
    if File.exist?(git_path)
      FileUtils.rm_rf(git_path, secure: true)
      @db.delete_repo_by_name(reponame)
    end
  end

  def get_repo_short_info_by_id(id)
    @db.get_repo_info_by_id(id)
  end

  def clone_repo_master(id, path)
    @error = nil
    repo_info = @db.get_repo_info_by_id(id)
    unless repo_info.nil?
      git_path = File.join(@path, repo_info[:reponame] + ".git")
      if File.exist?(git_path)
        repo = Rugged::Repository.new(git_path)
        if repo.empty?
          @error = "Репозиторий пустой, нельзя добавить в проект пустой репозиторий"
        else
          if File.exist?(path)
            FileUtils.rm_rf(path, secure: true)
          end
          Dir.mkdir(path)
          Rugged::Repository.clone_at(repo.path, path)
        end
      else
        @error = "Файла репозитория не существует"
      end
    else
      @error = "Нет информации о репозитории"
    end
    @error
  end

  def is_repos_sync(repo_name, prj_repo_path)
    res = false
    repo = Rugged::Repository.new(prj_repo_path)
    git_path = File.join(@path, repo_name + ".git")
    bare_repo = Rugged::Repository.new(git_path)
    res = (bare_repo.head.target.tree.oid == repo.head.target.tree.oid)
    res
  end
end
