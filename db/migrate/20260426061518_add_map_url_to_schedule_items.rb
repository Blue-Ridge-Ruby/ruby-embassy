class AddMapUrlToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    # Idempotent: production database already has this column from a prior
    # schema:load, but `schema_migrations` did not record this version, which
    # caused a deploy crash loop (PG::DuplicateColumn). `if_not_exists` lets
    # the migration succeed in that drifted state so Rails records the version
    # and future deploys are clean.
    add_column :schedule_items, :map_url, :string, if_not_exists: true
  end
end
