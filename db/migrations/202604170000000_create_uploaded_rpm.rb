require "sequel"

Sequel.migration do
  change do
    create_table(:rpm_uploaded) do
      primary_key :id
      String :rpm, :null => false
      String :rpm_path, :null => false
      Datetime :create_at, default: Sequel.lit("CURRENT_TIMESTAMP")
      foreign_key :proj_id, :projects, :key => :id
    end

  end
end
