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

ActiveRecord::Schema.define(version: 20140625070348) do

  create_table "commands", force: true do |t|
    t.text     "command",    limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "project_id"
  end

  create_table "deploys", force: true do |t|
    t.integer  "stage_id",   null: false
    t.integer  "job_id",     null: false
    t.string   "reference",  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "buddy"
  end

  add_index "deploys", ["created_at"], name: "index_deploys_on_created_at", using: :btree
  add_index "deploys", ["job_id"], name: "index_deploys_on_job_id", using: :btree

  create_table "flowdock_flows", force: true do |t|
    t.string   "name",       null: false
    t.string   "token",      null: false
    t.integer  "stage_id",   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "jobs", force: true do |t|
    t.text     "command",                                           null: false
    t.integer  "user_id",                                           null: false
    t.integer  "project_id",                                        null: false
    t.string   "status",                        default: "pending"
    t.text     "output",     limit: 1073741823
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "commit"
  end

  add_index "jobs", ["project_id"], name: "index_jobs_on_project_id", using: :btree

  create_table "locks", force: true do |t|
    t.integer  "stage_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "description"
  end

  create_table "new_relic_applications", force: true do |t|
    t.string  "name"
    t.integer "stage_id"
  end

  add_index "new_relic_applications", ["stage_id", "name"], name: "index_new_relic_applications_on_stage_id_and_name", unique: true, using: :btree

  create_table "projects", force: true do |t|
    t.string   "name",           null: false
    t.string   "repository_url", null: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "token"
    t.string   "release_branch"
  end

  add_index "projects", ["token"], name: "index_projects_on_token", using: :btree

  create_table "releases", force: true do |t|
    t.integer  "project_id",              null: false
    t.string   "commit",                  null: false
    t.integer  "number",      default: 1
    t.integer  "author_id",               null: false
    t.string   "author_type",             null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "releases", ["project_id", "number"], name: "index_releases_on_project_id_and_number", unique: true, using: :btree

  create_table "stage_commands", force: true do |t|
    t.integer  "stage_id"
    t.integer  "command_id"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stages", force: true do |t|
    t.string   "name",                                        null: false
    t.integer  "project_id",                                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notify_email_address"
    t.integer  "order"
    t.datetime "deleted_at"
    t.boolean  "confirm",                     default: true
    t.string   "datadog_tags"
    t.boolean  "update_github_pull_requests"
    t.boolean  "deploy_on_release",           default: false
  end

  create_table "stars", force: true do |t|
    t.integer  "user_id",    null: false
    t.integer  "project_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "stars", ["user_id", "project_id"], name: "index_stars_on_user_id_and_project_id", unique: true, using: :btree

  create_table "users", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_id",     default: 0, null: false
    t.string   "token"
    t.datetime "deleted_at"
    t.string   "external_id"
  end

  add_index "users", ["external_id"], name: "index_users_on_external_id", unique: true, using: :btree

  create_table "webhooks", force: true do |t|
    t.integer  "project_id", null: false
    t.integer  "stage_id",   null: false
    t.string   "branch",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "webhooks", ["project_id", "branch"], name: "index_webhooks_on_project_id_and_branch", using: :btree
  add_index "webhooks", ["stage_id", "branch"], name: "index_webhooks_on_stage_id_and_branch", unique: true, using: :btree

end
