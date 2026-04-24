# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_23_145241) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "plan_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "schedule_item_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["schedule_item_id"], name: "index_plan_items_on_schedule_item_id"
    t.index ["user_id", "schedule_item_id"], name: "index_plan_items_on_user_id_and_schedule_item_id", unique: true
    t.index ["user_id"], name: "index_plan_items_on_user_id"
  end

  create_table "schedule_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "day", null: false
    t.text "description"
    t.boolean "flexible", default: false, null: false
    t.string "host"
    t.boolean "is_public", default: false, null: false
    t.integer "kind", null: false
    t.string "location"
    t.string "slug"
    t.integer "sort_time"
    t.string "time_label"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_schedule_items_on_created_by_id"
    t.index ["day", "sort_time"], name: "index_schedule_items_on_day_and_sort_time"
    t.index ["is_public"], name: "index_schedule_items_on_is_public"
    t.index ["slug"], name: "index_schedule_items_on_slug", unique: true, where: "(slug IS NOT NULL)"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "role", default: 0, null: false
    t.string "tito_account_slug"
    t.string "tito_event_slug"
    t.string "tito_ticket_slug"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["tito_ticket_slug"], name: "index_users_on_tito_ticket_slug", unique: true
  end

  add_foreign_key "plan_items", "schedule_items"
  add_foreign_key "plan_items", "users"
  add_foreign_key "schedule_items", "users", column: "created_by_id"
end
