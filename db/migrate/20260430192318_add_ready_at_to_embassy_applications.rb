class AddReadyAtToEmbassyApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :embassy_applications, :ready_at, :datetime
  end
end
