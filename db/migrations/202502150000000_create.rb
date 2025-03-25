require "sequel"

Sequel.migration do
  change do
    create_table(:repos) do
      primary_key :id
      String :reponame, :null => false, :unique => true
      String :descr, text: true
      Datetime :create_at, default: Sequel.lit("CURRENT_TIMESTAMP")
      Integer :public
    end

    create_table(:projects) do
      primary_key :id
      String :projname
      String :descr, text: true
      Integer :public
      String :remote_address, text: true
      String :remote_command, text: true
      Datetime :create_at, default: Sequel.lit("CURRENT_TIMESTAMP")
    end

    create_table(:repos_projects) do
      foreign_key :proj_id, :projects, :key => :id
      foreign_key :repo_id, :repos, :key => :id
      primary_key [:proj_id, :repo_id]
    end

    create_table(:recips) do
      primary_key :id
      String :content, text: true
      String :filepath, text: true
      String :descr, text: true
      Datetime :create_at, default: Sequel.lit("CURRENT_TIMESTAMP")
    end

    create_table(:repos_recips) do
      foreign_key :repo_id, :repos, :key => :id
      foreign_key :recip_id, :recips, :key => :id
      primary_key [:recip_id, :repo_id]
    end

    create_table(:rpms) do
      primary_key :id
      String :savepath, text: true
      String :rpmname, text: true
      Integer :sign
      String :signpath, text: true
      String :filehash, text: true
      foreign_key :repo_id, :repos, :key => :id
    end

    create_table(:buildtask) do
      primary_key :id
      foreign_key :repo_id, :repos, :key => :id
      foreign_key :proj_id, :projects, :key => :id
      Datetime :create_at, default: Sequel.lit("CURRENT_TIMESTAMP")
      String :logpath, text: true
      Integer :result
      String :errlogpath, text: true
    end

    create_table(:build_rpm) do
      foreign_key :build_id, :buildtask, :key => :id
      foreign_key :rpm_id, :rpms, :key => :id
      primary_key [:build_id, :rpm_id]
    end

    create_table(:projects_projects) do
      foreign_key :proj_id, :projects, :key => :id
      foreign_key :proj_id_repository, :projects, :key => :id
      primary_key [:proj_id, :proj_id_repository]
    end

    create_table(:projects_repos_spec) do
      foreign_key :proj_id, :projects, :key => :id
      foreign_key :repo_id, :repos, :key => :id
      String :spec_name, :null => false, text: true
      primary_key [:proj_id, :repo_id]
    end
  end
end
