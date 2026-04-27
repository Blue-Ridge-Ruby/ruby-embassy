class RenameLastSignInAtToLastSeenOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :last_sign_in_at, :last_seen_at
  end
end
