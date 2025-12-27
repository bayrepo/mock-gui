require "sequel"

Sequel.migration do
  change do
    alter_table(:buildtask) do
      add_column :buildstart, DateTime
      add_column :buildstop, DateTime
      set_column_allow_null :buildstart
      set_column_allow_null :buildstop
    end
  end
end