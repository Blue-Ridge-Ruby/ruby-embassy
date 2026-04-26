class AddPassportReceivedAtToEmbassyApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :embassy_applications, :passport_received_at, :datetime
  end
end
