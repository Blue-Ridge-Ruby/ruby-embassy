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

ActiveRecord::Schema[8.1].define(version: 2026_04_26_063932) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "embassy_application_answers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "embassy_application_id", null: false
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value_array", default: [], null: false
    t.text "value_text"
    t.index ["embassy_application_id", "question_id"], name: "index_embassy_application_answers_on_app_question_uniq", unique: true
    t.index ["embassy_application_id"], name: "index_embassy_application_answers_on_embassy_application_id"
    t.index ["question_id"], name: "index_embassy_application_answers_on_question_id"
  end

  create_table "embassy_applications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "drawn_question_ids", default: [], null: false
    t.bigint "embassy_booking_id", null: false
    t.bigint "notary_profile_id"
    t.datetime "passport_received_at"
    t.string "serial", null: false
    t.string "state", default: "draft", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["embassy_booking_id"], name: "index_embassy_applications_on_booking_uniq", unique: true
    t.index ["notary_profile_id"], name: "index_embassy_applications_on_notary_profile_id"
    t.index ["serial"], name: "index_embassy_applications_on_serial", unique: true
  end

  create_table "embassy_bookings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "mode", null: false
    t.bigint "plan_item_id", null: false
    t.bigint "schedule_item_id", null: false
    t.string "state", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["plan_item_id"], name: "index_embassy_bookings_on_plan_item_id"
    t.index ["schedule_item_id"], name: "index_embassy_bookings_on_schedule_item_id"
    t.index ["user_id", "schedule_item_id"], name: "index_embassy_bookings_on_user_id_and_schedule_item_id", unique: true
    t.index ["user_id"], name: "index_embassy_bookings_on_user_id"
  end

  create_table "notary_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "external_id", null: false
    t.text "followup_prompt"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_notary_profiles_on_external_id", unique: true
  end

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

  create_table "questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "field_type", null: false
    t.text "help"
    t.text "label", null: false
    t.integer "max_length"
    t.jsonb "options", default: [], null: false
    t.string "placeholder"
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.string "scope", default: "common", null: false
    t.integer "section", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_questions_on_external_id", unique: true
    t.index ["scope", "status"], name: "index_questions_on_scope_and_status"
    t.index ["section", "position"], name: "index_questions_on_section_and_position"
  end

  create_table "schedule_items", force: :cascade do |t|
    t.string "audience", default: "everyone", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "day", null: false
    t.text "description"
    t.integer "embassy_capacity"
    t.string "embassy_mode"
    t.boolean "flexible", default: false, null: false
    t.string "host"
    t.boolean "is_public", default: false, null: false
    t.integer "kind", null: false
    t.string "location"
    t.string "map_url"
    t.string "slug"
    t.integer "sort_time"
    t.string "time_label"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["audience"], name: "index_schedule_items_on_audience"
    t.index ["created_by_id"], name: "index_schedule_items_on_created_by_id"
    t.index ["day", "sort_time"], name: "index_schedule_items_on_day_and_sort_time"
    t.index ["is_public"], name: "index_schedule_items_on_is_public"
    t.index ["kind", "embassy_mode"], name: "index_schedule_items_on_kind_and_embassy_mode"
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

  add_foreign_key "embassy_application_answers", "embassy_applications"
  add_foreign_key "embassy_application_answers", "questions"
  add_foreign_key "embassy_applications", "embassy_bookings"
  add_foreign_key "embassy_applications", "notary_profiles"
  add_foreign_key "embassy_bookings", "plan_items"
  add_foreign_key "embassy_bookings", "schedule_items"
  add_foreign_key "embassy_bookings", "users"
  add_foreign_key "plan_items", "schedule_items"
  add_foreign_key "plan_items", "users"
  add_foreign_key "schedule_items", "users", column: "created_by_id"
end
