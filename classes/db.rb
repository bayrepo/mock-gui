require "sequel"

cfg_internal = IniConfig.new()
$DDB = Sequel.connect(cfg_internal.get_db)

class Repos < Sequel::Model(:repos)
end

class Recips < Sequel::Model(:recips)
end

class RepocRecips < Sequel::Model(:repos_recips)
end

class Projects < Sequel::Model(:projects)
end

class ReposProjects < Sequel::Model(:repos_projects)
end

class ProjectsReposSpec < Sequel::Model(:projects_repos_spec)
end

class ProjectsProjects < Sequel::Model(:projects_projects)
end

class BuildTask < Sequel::Model(:buildtask)
end

class Rpms < Sequel::Model(:rpms)
end

class BuildRpms < Sequel::Model(:build_rpm)
end

class DBase
  attr :error, :last_id, :cfg

  def initialize(cfg)
    @cfg = cfg
  end

  def creategit(project_name, description)
    @error = nil
    data = Repos.where(reponame: project_name).first
    if data.nil?
      id = Repos.insert(reponame: project_name, descr: description, public: 1)
      @last_id = id
    else
      @error = "Данный репозиторий уже существует"
    end
    @error
  end

  def get_repo_info_by_name(repo_name)
    Repos.where(reponame: repo_name).first
  end

  def get_repo_info_by_id(id)
    Repos[id]
  end

  def get_recips()
    Recips.order(:id).map do |item|
      { :fname => item[:filepath], :descr => item[:descr], :id => item[:id] }
    end
  end

  def delete_repo_by_name(repo_name)
    rep_id = Repos.where(reponame: repo_name).first
    unless rep_id[:id].nil?
      id = rep_id[:id]
      RepocRecips.where(repo_id: id).delete
      ReposProjects.where(repo_id: id).delete
      Repos.where(reponame: repo_name).delete
    end
  end

  def createrecip(filepath, description, codedata, gitlist)
    error_data = nil
    filepath_san = sanitize_rcptname(filepath)
    is_data = Recips.where(filepath: filepath_san).first
    if codedata.nil? || codedata.strip == ""
      error_data
    else
      if is_data.nil?
        id = Recips.insert(filepath: filepath_san, descr: description, content: codedata)
        @last_id = id
        if !gitlist.nil? && gitlist.length > 0
          gitlist.each do |item|
            data = Repos.where(id: item.to_i).first
            unless data.nil?
              RepocRecips.insert(repo_id: data[:id], recip_id: id)
            end
          end
        end
        error_data
      else
        "Рецепт с таким именем #{filepath_san} уже существует"
      end
    end
  end

  def updaterecip(id, filepath, description, codedata, gitlist)
    error_data = nil
    filepath_san = sanitize_rcptname(filepath)
    is_data = Recips.where(filepath: filepath_san).first
    if codedata.nil? || codedata.strip == ""
      error_data
    else
      unless is_data.nil?
        Recips.where(id: id.to_i).update(filepath: filepath_san, descr: description, content: codedata)
        RepocRecips.where(recip_id: id.to_i).delete
        if !gitlist.nil? && gitlist.length > 0
          gitlist.each do |item|
            data = Repos.where(id: item.to_i).first
            unless data.nil?
              RepocRecips.insert(repo_id: data[:id], recip_id: id)
            end
          end
        end
        error_data
      else
        "Рецепт с таким именем #{filepath_san} не существует"
      end
    end
  end

  def get_rcp_info_by_id(rcpi_id)
    info = Recips[rcpi_id.to_i]
    gits = RepocRecips.where(recip_id: info[:id])
    info[:repos_list] = gits.map { |item| item[:repo_id].to_s }
    info
  end

  def delete_rcp(id)
    RepocRecips.where(recip_id: id.to_i).delete
    Recips.where(id: id.to_i).delete
  end

  def proj_list
    Projects.order(:id).all
  end

  def proj(id)
    Projects[id]
  end

  def proj_create(proj_name, proj_descr, nopublic, tmpbld)
    @error = nil
    data = Projects.where(projname: proj_name).first
    if data.nil?
      public_proj = 1
      unless nopublic.nil?
        public_proj = 0
      end
      tmpbld_proj = 1
      if tmpbld.nil?
        tmpbld_proj = 0
      end
      id = Projects.insert(projname: proj_name, descr: proj_descr, public: public_proj, tmpstpbuild: tmpbld_proj)
      @last_id = id
    else
      @error = "Данный проект уже существует"
    end
    @error
  end

  def get_gits_for_projects(id)
    result = []
    git_list = ReposProjects.where(proj_id: id.to_i).all
    unless git_list.nil?
      result = git_list.map do |item|
        Repos[item[:repo_id]]
      end.reject do |item|
        item.nil?
      end
    end
    result
  end

  def save_git_project(prj_id, git_id)
    result = ReposProjects.where(proj_id: prj_id, repo_id: git_id).first
    if result.nil?
      id = ReposProjects.insert(proj_id: prj_id, repo_id: git_id)
      @last_id = id
    end
  end

  def get_project_repo_spec(prj_id, git_id)
    ProjectsReposSpec.where(proj_id: prj_id.to_i, repo_id: git_id.to_i).first
  end

  def save_project_repo_spec(prj_id, git_id, spec)
    rep = ProjectsReposSpec.where(proj_id: prj_id.to_i, repo_id: git_id.to_i).first
    if rep.nil?
      id = ProjectsReposSpec.insert(proj_id: prj_id.to_i, repo_id: git_id.to_i, spec_name: spec)
      @last_id = id
    else
      ProjectsReposSpec.where(proj_id: prj_id.to_i, repo_id: git_id.to_i).update(spec_name: spec)
      @last_id = nil
    end
  end

  def delete_project_repo_spec(prj_id, git_id)
    ProjectsReposSpec.where(proj_id: prj_id.to_i, repo_id: git_id.to_i).delete
  end

  def get_projects_links(prj_id)
    ProjectsProjects.where(proj_id: prj_id.to_i).all
  end

  def delete_linked_projects(prj_id)
    ProjectsProjects.where(proj_id: prj_id.to_i).delete
  end

  def delete_linked_projects_with_id(prj_id, prj_id_link)
    ProjectsProjects.where(proj_id: prj_id.to_i, proj_id_repository: prj_id_link.to_i).delete
  end

  def save_linked_projects(prj_id, prj_id_link)
    item = ProjectsProjects.where(proj_id: prj_id.to_i, proj_id_repository: prj_id_link.to_i).first
    if item.nil?
      id = ProjectsProjects.insert(proj_id: prj_id.to_i, proj_id_repository: prj_id_link.to_i)
      @last_id = id
    end
  end

  def get_git_recips(git_id)
    res = []
    recip = RepocRecips.where(repo_id: git_id.to_i).all
    unless recip.nil?
      res = recip.map do |item|
        rcp_info = Recips[item[:recip_id]]
        rcp_info
      end
    end
    res
  end

  #result = 0 (in progress), 1 (stopped - error), 2 (stopped - success)
  def create_build_task(prj_id, git_id, proj_path)
    id = BuildTask.insert(repo_id: git_id.to_i, proj_id: prj_id.to_i, logpath: "", errlogpath: "", result: 0)
    @last_id = id
    BuildTask.where(id: id).update(logpath: File.join(proj_path, "#{id}"), errlogpath: File.join(proj_path, "#{id}", "process.log"))
  end

  def update_build_task_status(build_id, status)
    BuildTask.where(id: build_id.to_i).update(result: status.to_i)
  end

  def update_build_task_error_log(build_id, path)
    BuildTask.where(id: build_id.to_i).update(errlogpath: path)
  end

  def get_build_task_process_log(build_id)
    BuildTask.where(id: build_id.to_i).first
  end

  def before_fork()
    Sequel::DATABASES.each(&:disconnect)
  end

  def after_fork()
    $DDB = Sequel.connect(@cfg.get_db)
  end

  def save_rpm(build_id, path_to_rpm, rpm_name, git_id, sha256)
    id = Rpms.insert(savepath: path_to_rpm, rpmname: rpm_name, sign: 0, signpath: "", repo_id: git_id.to_i, filehash: sha256)
    @last_id = id
    BuildRpms.insert(build_id: build_id.to_i, rpm_id: id)
  end

  def get_gits_rpms()
    $DDB["select t1.id, t1.reponame, count(*) as packages from repos as t1 join rpms as t2 on t2.repo_id = t1.id group by t1.id, t1.reponame order by t1.id desc"].all
  end

  def get_rpms_for_git(git_id)
    $DDB["select t2.id as rpmid, t2.rpmname, t1.reponame as repoid, t4.id as builid, t4.proj_id as prjid, t4.create_at from repos as t1 join rpms as t2 on t2.repo_id = t1.id join build_rpm as t3 on t3.rpm_id = t2.id join buildtask as t4 on t4.id = t3.build_id where t1.id = ? and t2.savepath not like '%.src.rpm' order by t4.id desc, t2.rpmname", git_id.to_i].all
  end

  def get_rpm_info(rpm_id)
    Rpms[rpm_id.to_i]
  end

  def get_rpm_build(rpm_id)
    bld_info = BuildRpms.where(rpm_id: rpm_id.to_i).first
    if bld_info.nil?
      nil
    else
      bld_info[:build_id]
    end
  end

  def get_rpm_srpms(rpm_id)
    bld_info = BuildRpms.where(rpm_id: rpm_id.to_i).first
    if bld_info.nil?
      nil
    else
      bld_info[:build_id]
      result = BuildRpms.where(build_id: bld_info[:build_id].to_i)
      if result.nil?
        nil
      else
        result.each do |item|
          rpm_p = Rpms[item[:rpm_id].to_i]
          unless rpm_p.nil?
            if rpm_p[:savepath] =~ /\.src\.rpm$/
              return rpm_p
            end
          end
        end
      end
      nil
    end
  end

  def get_builds()
    $DDB["select t1.id as buildid, t1.create_at as createat, t1.result as state, t2.reponame as reponame, t2.id as gitid, t3.id as projid, t3.projname as prjname, count(*) as pkgcnt from buildtask as t1 join repos as t2 on t1.repo_id = t2.id join projects as t3 on t1.proj_id = t3.id left join build_rpm as t4 on t4.build_id = t1.id group by buildid, createat, state, reponame, projid, prjname, gitid order by t1.id desc"].all
  end

  def get_build_info(build_id)
    BuildTask[build_id.to_i]
  end

  def get_rpms_for_build(build_id)
    bld_info = BuildRpms.where(build_id: build_id.to_i)
    bld_info.map do |item|
      result = Rpms[item[:rpm_id]]
      result[:fname] = File.basename(result[:savepath])
      result
    end
  end

  def get_rpms()
    Rpms.order(:id).all
  end

  def get_builds_for_project(prj_id)
    $DDB["select t1.id as buildid, t1.create_at as createat, t1.result as state, t2.reponame as reponame, t2.id as gitid, t3.id as projid, t3.projname as prjname, count(*) as pkgcnt from buildtask as t1 join repos as t2 on t1.repo_id = t2.id join projects as t3 on t1.proj_id = t3.id left join build_rpm as t4 on t4.build_id = t1.id where t1.proj_id = ? group by buildid, createat, state, reponame, projid, prjname, gitid order by t1.id desc", prj_id.to_i].all
  end

  def get_builds_for_project_git(prj_id, git_id)
    $DDB["select t1.id as buildid, t1.create_at as createat, t1.result as state, t2.reponame as reponame, t2.id as gitid, t3.id as projid, t3.projname as prjname, count(*) as pkgcnt from buildtask as t1 join repos as t2 on t1.repo_id = t2.id join projects as t3 on t1.proj_id = t3.id left join build_rpm as t4 on t4.build_id = t1.id where t1.proj_id = ? and t1.repo_id = ? group by buildid, createat, state, reponame, projid, prjname, gitid order by t1.id desc", prj_id.to_i, git_id.to_i].all
  end

  def delete_git_from_project(prj_id, git_id)
    ReposProjects.where(proj_id: prj_id.to_i, repo_id: git_id.to_i).delete
    ProjectsReposSpec.where(proj_id: prj_id.to_i, repo_id: git_id.to_i).delete
  end

  def delete_project(prj_id)
    ReposProjects.where(proj_id: prj_id.to_i).delete
    ProjectsReposSpec.where(proj_id: prj_id.to_i).delete
    builds = BuildTask.where(proj_id: prj_id.to_i)
    builds.each do |item|
      rpms = BuildRpms.where(build_id: item[:id])
      Rpms.where(id: rpms[:rpm_id]).delete
    end
    BuildTask.where(proj_id: prj_id.to_i).delete
    Projects.where(id: prj_id.to_i).delete
  end

  def projects_with_current_as_link(prj_id)
    ProjectsProjects.where(proj_id_repository: prj_id.to_i).all
  end

  def get_rpm_info_by_hash(hash)
    Rpms.where(filehash: hash).first
  end

  def update_rpm_sign(rpm_id, sign_path)
    Rpms.where(id: rpm_id.to_i).update(sign: 1, signpath: sign_path)
  end

  def set_project_address(prj_id, address)
    Projects.where(id: prj_id.to_i).update(remote_address: address)
  end

  def get_gits()
    Repos.all
  end

  def delete_git_by_id(id)
    Repos.where(id: id.to_i).delete
  end
end
