class AddEstimatedCostToGroundReports < ActiveRecord::Migration[8.1]
  def change
    add_column :ground_reports, :estimated_cost, :decimal, precision: 12, scale: 2
  end
end
