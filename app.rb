# coding: utf-8

hestiacp_ruby_gem_version = "3.3.0"
Gem.paths = {
  "GEM_HOME" => "#{__dir__}/vendor/bundle/ruby/#{hestiacp_ruby_gem_version}",
  "GEM_PATH" => "#{__dir__}/vendor/bundle/ruby/#{hestiacp_ruby_gem_version}",
}

require "rubygems"
require "sinatra"
require "puma"
require "ptools"

require_relative "classes/config"
require_relative "classes/gitinfo"
require_relative "classes/db"
require_relative "classes/systeminfo"
require_relative "classes/utilities"
require_relative "classes/projects"
require_relative "classes/configs"

configure do
  log_file = File.new("logs/actions.log", "a+")

  STDOUT.reopen(log_file)
  STDERR.reopen(log_file)

  STDOUT.sync = true
  STDERR.sync = true
end

def print_error_page(error_status, error_meaasge)
  @page_name = "Ошибка выполнения"
  @status_err = error_status
  @error_msg = error_meaasge
  halt erb(:page5xx)
end

cfg = IniConfig.new()
db = DBase.new(cfg)

set :bind, "0.0.0.0"
set :port, cfg.get_port
set :public_folder, File.dirname(__FILE__) + "/public"
use Rack::Session::Pool, :expire_after => 2592000

get "/" do
  @page_name = "Система сборки rpm пакетов"
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    prj = ProjectsActions.new(cfg.get_projects_path, db)
    if prj.path.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      repo_data = repo.getrepos
      @repos_number = repo_data.length
      @rcp_number = db.get_recips.length
      @prj_number = prj.get_projects.length
      @rpm_number = db.get_rpms.length
      erb :index
    end
  end
end

get "/repos/:reponame/:branch" do
  @page_name = params["reponame"]
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    tmp_result = repo.repo_info(params["reponame"], params["branch"])
    if tmp_result[:error].nil?
      @repo_data = tmp_result
      @ip_addr = systeminfo_get_ip
      @user_name = systeminfo_get_username
      @path_to_repo = File.join(repo.path, params["reponame"] + ".git")
      erb :gitinfo
    else
      print_error_page(503, tmp_result[:error])
    end
  end
end

get "/repos/:reponame" do
  @page_name = params["reponame"]
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    tmp_result = repo.repo_info(params["reponame"])
    if tmp_result[:error].nil?
      @repo_data = tmp_result
      @ip_addr = systeminfo_get_ip
      @user_name = systeminfo_get_username
      @path_to_repo = File.join(repo.path, params["reponame"] + ".git")
      erb :gitinfo
    else
      print_error_page(503, tmp_result[:error])
    end
  end
end

post "/gitdelete/:reponame" do
  input_name = params["reponamedup"]
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    if params["reponame"] == input_name
      repo.delete_repo(input_name)
    end
    redirect "/repos"
  end
end

get "/gitdelete" do
  redirect "/repos"
end

get "/repos" do
  @page_name = "Список доступных git репозиториев"
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    @repo_data = repo.getrepos
    erb :gits
  end
end

get "/gitcreate" do
  @page_name = "Создать новый пустой git репозиторий"
  @error_data = session[:gitcreate_error]
  session[:gitcreate_error] = nil
  erb :newgit
end

post "/gitcreate" do
  if request.form_data?
    if params["gitname"].nil?
      session[:gitcreate_error] = "Не задано имя репозитория"
    else
      filename = sanitize_filename(params["gitname"])
      if filename != ""
        repo = GitRepo.new(cfg.get_repo, db)
        if repo.path.nil?
          print_error_page(503, "Путь к репозиториям не существует")
        else
          if repo.create_git(filename, params["gitdescr"]) != 0
            session[:gitcreate_error] = repo.error
          else
            redirect "/repos"
            return
          end
        end
      else
        session[:gitcreate_error] = "Название репозитория должно содержать только символы a-z, A-Z. 0-9 и _"
      end
    end
  end
  redirect "/gitcreate"
end

get "/recips" do
  @page_name = "Список доступных сценариев сборки"
  @rcp_data = db.get_recips
  erb :receips
end

get "/recips/:rcp_id" do
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    @repo_data = repo.getrepos
    @rcp_id = params["rcp_id"]
    info = db.get_rcp_info_by_id(@rcp_id)
    @page_name = info[:filepath]
    @rcp_name = info[:filepath]
    if session[:rcp_old_description].nil?
      @old_filepath = info[:filepath]
    else
      @old_filepath = session[:rcp_old_filepath]
    end
    if session[:rcp_old_description].nil?
      @old_description = info[:descr]
    else
      @old_description = session[:rcp_old_description]
    end
    if session[:rcp_old_codedata].nil?
      @old_codedata = info[:content]
    else
      @old_codedata = session[:rcp_old_codedata]
    end
    if session[:rcp_old_gitlst].nil?
      @old_gitlst = info[:repos_list]
    else
      @old_gitlst = session[:rcp_old_gitlst]
    end
    @error_data = session[:rcpcreate_error]
    session[:rcpcreate_error] = nil
    session[:rcp_old_filepath] = nil
    session[:rcp_old_description] = nil
    session[:rcp_old_codedata] = nil
    session[:rcp_old_gitlst] = nil
    erb :rcpedit
  end
end

post "/recips/:rcp_id" do
  rcp_id = params["rcp_id"]
  session[:rcp_old_filepath] = params["filepath"]
  session[:rcp_old_description] = params["description"]
  session[:rcp_old_codedata] = params["codedata"]
  session[:rcp_old_gitlst] = params["gitlst"]
  if params["filepath"].nil? || params["description"].nil? || params["filepath"].strip == "" || params["description"].strip == ""
    session[:rcpcreate_error] = "Имя рецепта и описание не должны быть пустыми"
    redirect url("/recips/#{rcp_id}")
  else
    @error_data = db.updaterecip(rcp_id, params["filepath"], params["description"], params["codedata"], params["gitlst"])
    unless @error_data.nil?
      session[:rcpcreate_error] = @error_data
      redirect url("/recips/#{rcp_id}")
    else
      session[:rcp_old_filepath] = nil
      session[:rcp_old_description] = nil
      session[:rcp_old_codedata] = nil
      session[:rcp_old_gitlst] = nil
      redirect "/recips"
    end
  end
end

post "/rcpdelete/:rcp_id" do
  input_name = params["rcpnamedup"]
  rcp_id = params["rcp_id"]
  info = db.get_rcp_info_by_id(rcp_id)
  if info.nil?
    print_error_page(404, "Рецепта не существует")
  else
    if info[:filepath] == input_name
      db.delete_rcp(rcp_id)
    end
    redirect "/recips"
  end
end

post "/rcpdelete" do
  redirect "/recips"
end

get "/rcpcreate" do
  @page_name = "Создать новый рецепт"
  @old_filepath = session[:rcp_old_filepath]
  @old_description = session[:rcp_old_description]
  @old_codedata = session[:rcp_old_codedata]
  @old_gitlst = session[:rcp_old_gitlst]
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    @repo_data = repo.getrepos
    @error_data = session[:rcpcreate_error]
    session[:rcpcreate_error] = nil
    erb :rcpcrt
  end
end

post "/rcpcreate" do
  session[:rcp_old_filepath] = params["filepath"]
  session[:rcp_old_description] = params["description"]
  session[:rcp_old_codedata] = params["codedata"]
  session[:rcp_old_gitlst] = params["gitlst"]
  if params["filepath"].nil? || params["description"].nil? || params["filepath"].strip == "" || params["description"].strip == ""
    session[:rcpcreate_error] = "Имя рецепта и описание не должны быть пустыми"
    redirect "/rcpcreate"
  else
    codedata = params["codedata"].gsub(/\r$/, "")
    @error_data = db.createrecip(params["filepath"], params["description"], codedata, params["gitlst"])
    unless @error_data.nil?
      session[:rcpcreate_error] = @error_data
      redirect "/rcpcreate"
    else
      session[:rcp_old_filepath] = nil
      session[:rcp_old_description] = nil
      session[:rcp_old_codedata] = nil
      session[:rcp_old_gitlst] = nil
      redirect "/recips"
    end
  end
end

get "/bldcfg" do
  @page_name = "Список конфигураций сборки"
  cfgs = ConfigsList.new(cfg)
  result = cfgs.get_configs
  @list_global = result[:global]
  @list_local = result[:local]
  @list_selected = result[:selected]
  erb :cfgslist
end

get "/bldcfginfo" do
  @filename = params["info"]
  if @filename.nil?
    print_error_page(503, "Не задано имя конфигурационного файла")
  else
    unless check_safe_path(@filename)
      print_error_page(503, "Доступ к файлу #{@filename} запрещен")
    else
      unless File.exist?(@filename)
        print_error_page(503, "Файл #{@filename} не существует")
      else
        @page_name = @filename
        @content = File.readlines(@filename)
        erb :cfgsinfo
      end
    end
  end
end

get "/projs" do
  @page_name = "Список проектов"
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    @prj_list = prj.get_projects
    erb :prjlist
  end
end

get "/prjcreate" do
  @page_name = "Создать новый проект"
  @old_name = session[:prj_old_name]
  @old_description = session[:prj_old_description]
  @old_list = session[:prj_old_list]
  cfgs = ConfigsList.new(cfg)
  result = cfgs.get_configs
  @global_list = result[:global]
  @local_list = result[:local]
  @old_nopublic = session[:prj_old_nopublic]
  @error_data = session[:prjcreate_error]
  @old_tmpbld = session[:prj_old_tmpbld]
  session[:prjcreate_error] = nil
  erb :prjcrt
end

post "/prjcreate" do
  session[:prj_old_name] = params["projname"]
  session[:prj_old_description] = params["description"]
  session[:prj_old_list] = params["conflist"]
  session[:prj_old_nopublic] = params["nopublic"]
  session[:prj_old_tmpbld] = params["tmpbld"]
  if params["projname"].nil? || params["description"].nil? || params["projname"].strip == "" || params["description"].strip == "" || params["conflist"].nil? || params["conflist"].strip == ""
    session[:rcpcreate_error] = "Имя проекта, описание и окружение сборки не должны быть пустыми"
    redirect "/prjcreate"
  else
    prj = ProjectsActions.new(cfg.get_projects_path, db)
    result = prj.create_project(params["projname"], params["description"], params["conflist"], params["nopublic"], params["tmpbld"])
    if result != 0
      session[:prjcreate_error] = prj.error
      redirect "/prjcreate"
    else
      session[:prj_old_name] = nil
      session[:prj_old_description] = nil
      session[:prj_old_list] = nil
      session[:prj_old_nopublic] = nil
      session[:prj_old_tmpbld] = nil
      redirect "/projs"
    end
  end
end

get "/prjedit/:id" do
  unless session[:prj_modal_text].nil?
    @modal_info = session[:prj_modal_info]
    @modal_text = session[:prj_modal_text]
    session[:prj_modal_info] = nil
    session[:prj_modal_text] = nil
  end
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        @page_name = prj_info[:projname]
        @proj_name = prj_info[:projname]
        @proj_descr = prj_info[:descr]
        @proj_id = prj_info[:id]
        @proj_public = prj_info[:public]
        @proj_tmpbuild = prj_info[:tmpstpbuild]
        repo_lst = repo.getrepos
        proj_repo_list = prj.get_project_gits(prj_info[:id], repo)
        @repo_list = repo_lst.reject do |item|
          fnd = false
          proj_repo_list.each do |item2|
            if item2[:id] == item[:id]
              fnd = true
              break
            end
          end
          fnd
        end
        @proj_repo = proj_repo_list
        erb :prjinfo
      end
    end
  end
end

post "/prjagit/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        proj_repo_list = prj.get_project_gits(prj_info[:id], repo)
        git_info = repo.get_repo_short_info_by_id(params["gitlist"].to_i)
        if git_info.nil?
          print_error_page(503, "Репозиторий исчез")
        else
          fnd = false
          proj_repo_list.each do |item|
            if item[:id] == git_info[:id]
              fnd = true
              break
            end
          end
          if fnd
            session[:prj_modal_info] = "Ошибка"
            session[:prj_modal_text] = "Данный git-репозиторий уже добавлен к проекту"
          else
            err = prj.add_git_to_project(prj_info[:id], git_info[:id], repo, git_info[:reponame])
            if err.nil?
              session[:prj_modal_info] = nil
              session[:prj_modal_text] = nil
            else
              session[:prj_modal_info] = "Ошибка добавления git проекта"
              session[:prj_modal_text] = err
            end
          end
        end
      end
    end
  end
  redirect back
end

get "/prjrgit/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        proj_repo_list = prj.get_project_gits(prj_info[:id], repo)
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        if git_info.nil?
          print_error_page(503, "Репозиторий исчез")
        else
          err = prj.renew_git_to_project(prj_info[:id], git_info[:id], repo, git_info[:reponame])
          if err.nil?
            session[:prj_modal_info] = nil
            session[:prj_modal_text] = nil
          else
            session[:prj_modal_info] = "Ошибка обновления git проекта"
            session[:prj_modal_text] = err
          end
        end
      end
    end
  end
  redirect back
end

get "/prjgitf/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        proj_repo_list = prj.get_project_gits(prj_info[:id], repo)
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        if git_info.nil?
          print_error_page(503, "Репозиторий исчез")
        else
          if params["p"].nil?
            filepath = ""
          else
            filepath = params["p"]
          end
          proj_path = prj.get_project_path_git(prj_info[:id], git_info[:reponame])
          f_path = File.join(proj_path, filepath)
          if File.exist?(f_path)
            if File.directory?(f_path)
              @file_content = []
              @files_list = Dir[File.join(f_path, "*")].map do |item|
                if File.directory?(item)
                  { :file => item.delete_prefix(proj_path + "/"), :isdir => true }
                else
                  { :file => item.delete_prefix(proj_path + "/"), :isdir => false }
                end
              end
            else
              if File.binary?(f_path)
                @file_content = ["Двоичный файл"]
              else
                @file_content = File.readlines(f_path)
              end
              @files_list = Dir[File.join(File.dirname(f_path), "*")].map do |item|
                if File.directory?(item)
                  { :file => item.delete_prefix(proj_path + "/"), :isdir => true }
                else
                  { :file => item.delete_prefix(proj_path + "/"), :isdir => false }
                end
              end
            end
            if filepath != ""
              if File.dirname(f_path) == proj_path
                fn = ""
              else
                if File.directory?(f_path)
                  fn = File.dirname(f_path).delete_prefix(proj_path + "/")
                else
                  f_path = File.dirname(f_path)
                  if File.dirname(f_path) == proj_path
                    fn = ""
                  else
                    fn = File.dirname(f_path).delete_prefix(proj_path + "/")
                  end
                end
              end
              @files_list = [{ :file => "..", :isdir => true, :fname => fn }] + @files_list
            end
            @page_name = "#{prj_info[:projname]} информация из репозитория #{git_info[:reponame]}"
            @proj_info = prj_info
            @proj_git_name = git_info
            @file_name = filepath
            erb :fileinfo
          else
            print_error_page(503, "Файл не существует")
          end
        end
      end
    end
  end
end

get "/prjcfg/:id" do
  unless session[:prjcfg_modal_text].nil?
    @modal_info = session[:prjcfg_modal_info]
    @modal_text = session[:prjcfg_modal_text]
    session[:prjcfg_modal_info] = nil
    session[:prjcfg_modal_text] = nil
  end
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      @page_name = "#{prj_info[:projname]} редактирование конфигурации сборки"
      @proj_name = prj_info[:projname]
      @proj_descr = prj_info[:descr]
      project_cfg = prj.get_project_config(params["id"])
      @project_cfg_tmpl = File.basename(project_cfg)
      @file_content = File.readlines(project_cfg).join("")
      @proj_id = prj_info[:id]
      erb :prjcfged
    end
  end
end

post "/prjcfg/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      pp params
      unless params["cancel"].nil?
        redirect "/prjedit/#{params["id"]}"
      else
        if params["cfginfo"].nil? || params["cfginfo"].strip == ""
          session[:prjcfg_modal_info] = "Ошибка сохранения файла"
          session[:prjcfg_modal_text] = "Содержимое файла не может быть пустым"
          redirect "/prjcfg/#{params["id"]}"
        else
          project_cfg = prj.get_project_config(params["id"])
          File.open(project_cfg, "w") { |f| f.write(params["cfginfo"]) }
          redirect "/prjcfg/#{params["id"]}"
        end
      end
    end
  end
end

get "/gitspec/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        spec_f = db.get_project_repo_spec(params["id"], params["git_id"])
        if spec_f.nil?
          @spec_file = ""
        else
          @spec_file = spec_f[:spec_name]
        end
        @page_name = "#{prj_info[:projname]} редактирование spec для git проекта #{git_info[:reponame]}"
        @proj_name = prj_info[:projname]
        @proj_descr = prj_info[:descr]
        @git_name = git_info[:reponame]
        @proj_id = prj_info[:id]
        @git_id = git_info[:id]
        git_path = prj.get_project_path_git(prj_info[:id], git_info[:reponame])
        @files_list = get_spec_files_in_dir(git_path)
        current_spec_data = db.get_project_repo_spec(prj_info[:id], git_info[:id])
        @current_spec = nil
        unless current_spec_data.nil?
          @current_spec = current_spec_data[:spec_name]
        end
        erb :prjspec
      end
    end
  end
end

post "/gitspec/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        unless params["cancel"].nil?
          redirect "/prjedit/#{params["id"]}"
        else
          unless params["save"].nil?
            save_spec = ""
            if params["useCustom"].nil?
              save_spec = params["filelst"].strip
            else
              save_spec = params["speccustom"].strip
            end
            if save_spec != ""
              db.save_project_repo_spec(prj_info[:id], git_info[:id], save_spec)
            end
            redirect "/prjedit/#{params["id"]}"
          else
            db.delete_project_repo_spec(prj_info[:id], git_info[:id])
            redirect "/prjedit/#{params["id"]}"
          end
        end
      end
    end
  end
end

get "/prjaddrepo/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      @page_name = "#{prj_info[:projname]} - добавить связанные проекты"
      @proj_name = prj_info[:projname]
      @proj_descr = prj_info[:descr]
      @proj_id = prj_info[:id]
      @projects_list = prj.get_related_projects_list(params["id"])
      @all_projects = prj.get_projects
      erb :prjprj
    end
  end
end

post "/prjaddrepo/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      unless params["cancel"].nil?
        redirect "/prjedit/#{params["id"]}"
      else
        if params["disableLinks"].nil?
          list_id = params["prjlst"]
          unless list_id.nil?
            current_list = prj.get_related_projects_list(params["id"])
            current_list_id = current_list.map { |item| item[:proj_id_repository] }
            new_ids = list_id - current_list_id
            removed_ids = current_list_id - list_id
            prj.save_linked_projects(params["id"], new_ids, removed_ids)
            prj.regenerate_linked_repos(params["id"])
          end
          redirect "/prjedit/#{params["id"]}"
        else
          prj.delete_linked_projects(params["id"])
          prj.regenerate_linked_repos(params["id"])
          redirect "/prjedit/#{params["id"]}"
        end
      end
    end
  end
end

get "/gitbld/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        @page_name = "#{prj_info[:projname]} - сборка #{git_info[:reponame]}"
        @proj_name = prj_info[:projname]
        @proj_descr = prj_info[:descr]
        @git_name = git_info[:reponame]
        @proj_id = params["id"]

        @build_id = prj.build_projects_git(prj_info[:id], git_info[:id], cfg.get_counter_path)

        if @build_id == 0
          print_error_page(503, "Ошибка создания или получения информации о сборке, возможно проблемы с файлом блокировки")
        else
          erb :prjbld
        end
      end
    end
  end
end

get "/buildinfo/:build_id" do
  content_type "text/plain"
  build_id = params["build_id"].to_i
  if build_id > 0
    info = db.get_build_task_process_log(build_id)
    unless info.nil?
      if File.exist?(info[:errlogpath])
        output = ""
        File.readlines(info[:errlogpath]).last(100).each do |line|
          output << line
        end
        output
      else
        "Файла для чтения сборки уже не существует #{info[:errlogpath]}"
      end
    else
      "Такого build id #{params["build_id"]} нет в базе"
    end
  else
    "Ошибка чтения build id #{params["build_id"]}"
  end
end

get "/buildinforaw/:build_id" do
  content_type "text/plain"
  build_id = params["build_id"].to_i
  if build_id > 0
    info = db.get_build_task_process_log(build_id)
    unless info.nil?
      if File.exist?(info[:errlogpath])
        send_file info[:errlogpath]
      else
        "Файла для чтения сборки уже не существует #{info[:errlogpath]}"
      end
    else
      "Такого build id #{params["build_id"]} нет в базе"
    end
  else
    "Ошибка чтения build id #{params["build_id"]}"
  end
end

get "/rpms" do
  @page_name = "Список доступных пакетов"
  @gits_rpms_list = db.get_gits_rpms
  erb :rpmlistglobal
end

get "/gitpackages/:git_id" do
  repo = GitRepo.new(cfg.get_repo, db)
  if repo.path.nil?
    print_error_page(503, "Путь к репозиториям не существует")
  else
    git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
    if git_info.nil?
      print_error_page(503, "Репозиторий исчез")
    else
      @page_name = "Список пакетов собранных из git репозитория #{git_info[:reponame]}"
      rpms_lst = db.get_rpms_for_git(params["git_id"])
      if params["p"].nil?
        @page = 1
      else
        @page = params["p"].to_i
        if @page < 1
          @page = 1
        end
      end
      if rpms_lst.nil?
        rpms_lst = []
      end
      items_per_page = cfg.get_items_per_page
      @rpms_list = rpms_lst[(@page - 1) * items_per_page, items_per_page]
      if @rpms_list.nil?
        @rpms_list = []
      end
      @max_pages = rpms_lst.length / items_per_page
      if (@max_pages * items_per_page) != rpms_lst.length
        @max_pages = @max_pages + 1
      end
      @git_id = params["git_id"]
      erb :rpmlistgit
    end
  end
end

get "/rpminfo/:rpm_id" do
  rpm_info = db.get_rpm_info(params["rpm_id"])
  if rpm_info.nil?
    print_error_page(503, "Пакета не существует")
  else
    @page_name = "Информация о пакете #{rpm_info[:rpmname]}"
    @rpm_data = rpm_info
    @repo_id = rpm_info[:repo_id]
    rpm_reader = RPMReader.new()
    rpm_pkg = rpm_reader.get_rpm_info(rpm_info[:savepath])
    if rpm_pkg[:error].nil?
      @build_id = db.get_rpm_build(params["rpm_id"])
      @pkg_info = rpm_pkg[:pkginfo]
      @rpms_info = db.get_rpm_srpms(params["rpm_id"])
      erb :rpminfo
    else
      print_error_page(503, "Ошибка чтения пакета #{rpm_info[:rpmname]}: #{rpm_pkg[:error]}")
    end
  end
end

get "/builds" do
  @page_name = "Список всех сборок"
  builds_lst = db.get_builds
  if params["p"].nil?
    @page = 1
  else
    @page = params["p"].to_i
    if @page < 1
      @page = 1
    end
  end
  if builds_lst.nil?
    builds_lst = []
  end
  items_per_page = cfg.get_items_per_page
  @builds_list = builds_lst[(@page - 1) * items_per_page, items_per_page]
  if @builds_list.nil?
    @builds_list = []
  end
  @max_pages = builds_lst.length / items_per_page
  if (@max_pages * items_per_page) != builds_lst.length
    @max_pages = @max_pages + 1
  end
  erb :buildslist
end

get "/buildinfof/:build_id" do
  build_info = db.get_build_info(params["build_id"])
  if build_info.nil?
    print_error_page(503, "Сборки не сущестует")
  else
    if build_info[:result] == 0
      redirect url("/buildinfo/#{params["build_id"].to_i}")
    else
      result_path = build_info[:logpath]
      if File.exist?(result_path)
        @logs_list = get_log_paths_success(result_path)
        @process_log = File.join(result_path, "process.log")
        @rpm_list = db.get_rpms_for_build(params["build_id"])
        unless params["file"].nil?
          file_name = params["file"]
        else
          file_name = @process_log
        end
        unless File.exist?(file_name)
          print_error_page(503, "Запрашиваемый файл отсутствует")
        else
          @file_content = []
          File.readlines(file_name).last(100).each do |line|
            @file_content << line
          end
          @file_disp = File.basename(file_name)
          @file_disp_raw = file_name
          @build_id = params["build_id"]
          @repo = db.get_repo_info_by_id(build_info[:repo_id])
          @proj = db.proj(build_info[:proj_id])
          erb :buildinfo
        end
      else
        print_error_page(503, "Для данной сборки уже не существует результатов")
      end
    end
  end
end

get "/buildinfofraw" do
  if params["file"].nil? || !File.exist?(params["file"])
    print_error_page(503, "Файл не найден")
  else
    if !File.binary?(params["file"]) && params["file"].start_with?(File.join(Dir.pwd(), cfg.get_projects_path))
      send_file params["file"]
    else
      print_error_page(503, "Файл не может быть скачан")
    end
  end
end

get "/prjbuilds/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    @prj = prj_info
    @page_name = "Список всех сборок для проекта #{prj_info[:projname]}"
    builds_lst = db.get_builds_for_project(params["id"])
    if params["p"].nil?
      @page = 1
    else
      @page = params["p"].to_i
      if @page < 1
        @page = 1
      end
    end
    if builds_lst.nil?
      builds_lst = []
    end
    items_per_page = cfg.get_items_per_page
    @builds_list = builds_lst[(@page - 1) * items_per_page, items_per_page]
    if @builds_list.nil?
      @builds_list = []
    end
    @max_pages = builds_lst.length / items_per_page
    if (@max_pages * items_per_page) != builds_lst.length
      @max_pages = @max_pages + 1
    end
    erb :prjbuildslist
  end
end

get "/prjrpm/:id" do
  @raw = nil
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if params["p"].nil?
      filepath = ""
    else
      filepath = params["p"]
    end
    proj_path = prj.get_project_repo(params["id"])
    f_path = File.join(proj_path, filepath)
    if File.exist?(f_path)
      if File.directory?(f_path)
        @file_content = []
        @files_list = Dir[File.join(f_path, "*")].reject do |item|
          item =~ /repodata$/
        end.map do |item|
          if File.directory?(item)
            { :file => item.delete_prefix(proj_path + "/"), :isdir => true }
          else
            { :file => item.delete_prefix(proj_path + "/"), :isdir => false }
          end
        end
      else
        if File.binary?(f_path)
          if f_path =~ /\.rpm$/
            rpm_rd = RPMReader.new
            rpm_info = rpm_rd.get_rpm_info(f_path)
            if rpm_info[:error].nil?
              @raw = f_path
              rpm_info = rpm_info[:pkginfo]
              @file_content = []
              @file_content << "Имя пакета: #{rpm_info.name}"
              @file_content << "Версия пакета: #{rpm_info.version}"
              @file_content << ""
              @file_content << "Changelog:"
              rpm_info.changelog.first(10).each do |entry|
                @file_content << "#{entry.time} #{entry.name}"
                @file_content << "#{entry.text}"
                @file_content << "---------------"
              end
              @file_content << "---------------"
              @file_content << "Файлы:"
              rpm_info.files.each do |file|
                @file_content << "#{file.path} (#{file.size})"
              end
              @file_content << "---------------"
              @file_content << "Зависимости:"
              rpm_info.provides.each do |item|
                @file_content << "Provides: #{item.name}"
              end
              rpm_info.requires.each do |item|
                @file_content << "Requires: #{item.name}"
              end
              rpm_info.obsoletes.each do |item|
                @file_content << "Obsoletes: #{item.name}"
              end
              rpm_info.conflicts.each do |item|
                @file_content << "Conflicts: #{item.name}"
              end
            else
              @file_content = ["Двоичный файл"]
            end
          else
            @file_content = ["Двоичный файл"]
          end
        else
          @file_content = File.readlines(f_path)
        end
        @files_list = Dir[File.join(File.dirname(f_path), "*")].map do |item|
          if File.directory?(item)
            { :file => item.delete_prefix(proj_path + "/"), :isdir => true }
          else
            { :file => item.delete_prefix(proj_path + "/"), :isdir => false }
          end
        end
      end
      if filepath != ""
        if File.dirname(f_path) == proj_path
          fn = ""
        else
          if File.directory?(f_path)
            fn = File.dirname(f_path).delete_prefix(proj_path + "/")
          else
            f_path = File.dirname(f_path)
            if File.dirname(f_path) == proj_path
              fn = ""
            else
              fn = File.dirname(f_path).delete_prefix(proj_path + "/")
            end
          end
        end
        @files_list = [{ :file => "..", :isdir => true, :fname => fn }] + @files_list
      end
      @page_name = "Список пакетов для репозитория #{prj_info[:projname]}"
      @proj_info = prj_info
      @file_name = filepath
      erb :repoinfo
    else
      print_error_page(503, "Файл не существует")
    end
  end
end

get "/prjdgit/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        @page_name = "Удалить репозиторий #{git_info[:reponame]} из проекта #{prj_info[:projname]} "
        @proj_name = prj_info[:projname]
        @git_name = git_info[:reponame]
        @proj_id = params["id"]
        @git_id = params["git_id"]

        erb :deletegitprj
      end
    end
  end
end

post "/prjdgit/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      if prj_info.nil?
        print_error_page(503, "Путь к проектам не существует")
      else
        git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
        if params["cancel"].nil? && params["delete"] == "delete" && !params["isdelete"].nil?
          err = prj.delete_git_from_project(params["id"], params["git_id"])
          unless err.nil?
            session[:prj_modal_info] = "Ошибка удаления git репозитория из проекта"
            session[:prj_modal_text] = err
          end
        end

        redirect "/prjedit/#{params["id"]}"
      end
    end
  end
end

get "/prjgitbld/:id/:git_id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    repo = GitRepo.new(cfg.get_repo, db)
    if repo.path.nil?
      print_error_page(503, "Путь к репозиториям не существует")
    else
      prj_info = prj.get_project(params["id"])
      git_info = repo.get_repo_short_info_by_id(params["git_id"].to_i)
      @git_data = git_info
      @prj = prj_info
      @git_id = params["git_id"]
      @page_name = "Список всех сборок для проекта #{prj_info[:projname]} и репозитория #{git_info[:reponame]}"
      builds_lst = db.get_builds_for_project_git(params["id"], params["git_id"])
      if params["p"].nil?
        @page = 1
      else
        @page = params["p"].to_i
        if @page < 1
          @page = 1
        end
      end
      if builds_lst.nil?
        builds_lst = []
      end
      items_per_page = cfg.get_items_per_page
      @builds_list = builds_lst[(@page - 1) * items_per_page, items_per_page]
      if @builds_list.nil?
        @builds_list = []
      end
      @max_pages = builds_lst.length / items_per_page
      if (@max_pages * items_per_page) != builds_lst.length
        @max_pages = @max_pages + 1
      end
      erb :prjbuildslistgit
    end
  end
end

get "/prjdelete/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      @page_name = "Удалить проект #{prj_info[:projname]} "
      @proj_name = prj_info[:projname]
      @proj_id = params["id"]

      erb :deleteprj
    end
  end
end

post "/prjdelete/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      if params["cancel"].nil? && params["delete"] == "delete" && !params["isdelete"].nil?
        err = prj.delete_project(params["id"])
        unless err.nil?
          session[:prj_modal_info] = "Ошибка удаления git репозитория из проекта"
          session[:prj_modal_text] = err
          redirect "/prjedit/#{params["id"]}"
        else
          redirect "/projs"
        end
      end
      redirect "/prjedit/#{params["id"]}"
    end
  end
end

get "/prjsign/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      gpgKeys = RepoManagerKeys.new(cfg.get_keys_path)
      if gpgKeys.check_key_exists
        @pass_exists = gpgKeys.check_password_exists
        @page_name = "Подписать проект #{prj_info[:projname]}"
        @proj_name = prj_info[:projname]
        @proj_id = params["id"]
        erb :signconfirm
      else
        @page_name = "Ошибка подписания проекта #{prj_info[:projname]}"
        erb :gpgerror
      end
    end
  end
end

post "/prjsign/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      if params["cancel"].nil? && params["sign"] == "sign"
        err = prj.sign_project(params["id"], cfg.get_keys_path, params["password"], "/prjsignview/#{prj_info[:id]}", cfg.get_repoview_path)
        unless err.nil?
          session[:prj_modal_info] = "Ошибка добавления подписи пакетов проекта"
          session[:prj_modal_text] = err
        end
      end
      redirect "/prjedit/#{params["id"]}"
    end
  end
end

get "/prjremoteaddr/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      @page_name = "Подписать проект #{prj_info[:projname]}"
      @proj_name = prj_info[:projname]
      @proj_id = params["id"]
      @addres = prj_info[:remote_address]
      erb :projremote
    end
  end
end

post "/prjremoteaddr/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      if params["cancel"].nil? && params["addr"] == "addr"
        err = prj.set_address(params["id"], params["address"])
        unless err.nil?
          session[:prj_modal_info] = "Ошибка установки адреса проекта"
          session[:prj_modal_text] = err
        end
      end
      if params["cancel"].nil? && params["reset"] == "reset"
        err = prj.set_address(params["id"], "")
        unless err.nil?
          session[:prj_modal_info] = "Ошибка установки адреса проекта"
          session[:prj_modal_text] = err
        end
      end
      redirect "/prjedit/#{params["id"]}"
    end
  end
end

get "/prjsignview/:id" do
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      gpgKeys = RepoManagerKeys.new(cfg.get_keys_path)
      if gpgKeys.check_key_exists
        redirect "/prjsignview/#{params["id"]}/"
      else
        @page_name = "Ошибка подписания проекта #{prj_info[:projname]}"
        erb :gpgerror
      end
    end
  end
end

get "/prjsignview/:id/*" do
  data_path = params[:splat]
  pp data_path
  if data_path.nil? || data_path.first.strip == ""
    data_path = "index.html"
  end
  prj = ProjectsActions.new(cfg.get_projects_path, db)
  if prj.path.nil?
    print_error_page(503, "Путь к проектам не существует")
  else
    prj_info = prj.get_project(params["id"])
    if prj_info.nil?
      print_error_page(503, "Путь к проектам не существует")
    else
      gpgKeys = RepoManagerKeys.new(cfg.get_keys_path)
      if gpgKeys.check_key_exists
        sign_path = prj.get_sign_path(params["id"])
        f_path = File.join(sign_path, data_path)
        if File.exist? (f_path)
          send_file f_path
        else
          status 404
        end
      else
        @page_name = "Ошибка подписания проекта #{prj_info[:projname]}"
        erb :gpgerror
      end
    end
  end
end

get "/sanitize" do
  #Подчистим гит проекты, которые есть в базе, но нет в файловой системе
  all_gits = db.get_gits
  deleted_items = 0
  unless all_gits.nil?
    repo = GitRepo.new(cfg.get_repo, db)
    repos = repo.getrepos
    list_for_delete = []
    all_gits.each do |item|
      find_item = false
      repos.each do |rep|
        if rep[:reponame] == item[:reponame]
          find_item = true
          break
        end
      end
      unless find_item
        list_for_delete << item[:id]
      end
    end
    deleted_items = deleted_items + list_for_delete.length
    list_for_delete.each do |item|
      db.delete_git_by_id(item)
    end
  end
  @deleted_items = deleted_items
  @page_name = "Очистка устаревших или потерянных записей базы данных"
  erb :sanitize
end

not_found do
  status 404
  @page_name = "Кто-то потерялся"
  @req_referer = request.referer
  erb :page404
end
