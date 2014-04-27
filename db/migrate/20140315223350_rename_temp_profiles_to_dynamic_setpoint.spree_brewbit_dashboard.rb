# This migration comes from spree_brewbit_dashboard (originally 20140315223025)
class RenameTempProfilesToDynamicSetpoint < ActiveRecord::Migration
  def change
    rename_column :temperature_points, :temperature_profile_id, :dynamic_setpoint_id
    
    rename_table :temperature_points, :dynamic_setpoint_step
    rename_table :temperature_profiles, :dynamic_setpoints
  end
end
