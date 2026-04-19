require "sequel"

Sequel.migration do
  change do

    create_table(:custom_build_script) do
      primary_key :id
      String :content, text: true
      String :filepath, text: true
      String :descr, text: true
      Datetime :create_at, default: Sequel.lit("CURRENT_TIMESTAMP")
      foreign_key :proj_id, :projects, :key => :id
      foreign_key :repo_id, :repos, :key => :id
    end

  end
end