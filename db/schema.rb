# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140108043655) do

  create_table "deploys", force: true do |t|
    t.integer  "stage_id",   null: false
    t.integer  "job_id",     null: false
    t.string   "commit",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "jobs", force: true do |t|
    t.text     "command",                        null: false
    t.integer  "user_id",                        null: false
    t.integer  "project_id",                     null: false
    t.string   "status",     default: "pending"
    t.text     "output"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "projects", force: true do |t|
    t.string   "name",           null: false
    t.string   "repository_url", null: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stages", force: true do |t|
    t.string   "name",                 null: false
    t.text     "command"
    t.integer  "project_id",           null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notify_email_address"
  end

  create_table "users", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_id",       default: 0, null: false
    t.string   "current_token"
  end

end
