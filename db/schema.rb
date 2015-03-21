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

ActiveRecord::Schema.define(version: 20150312110723) do

  create_table "commands", force: true do |t|
    t.text     "command",    limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "project_id"
  end

  create_table "deploy_groups", force: :cascade do |t|
    t.string   "name",           null: false
    t.integer  "environment_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "deploy_groups", ["environment_id"], name: "index_deploy_groups_on_environment_id"

  create_table "deploy_groups_stages", id: false, force: :cascade do |t|
    t.integer "deploy_group_id"
    t.integer "stage_id"
  end

  add_index "deploy_groups_stages", ["deploy_group_id"], name: "index_deploy_groups_stages_on_deploy_group_id"
  add_index "deploy_groups_stages", ["stage_id"], name: "index_deploy_groups_stages_on_stage_id"

  create_table "deploys", force: true do |t|
    t.integer  "stage_id",   null: false
    t.integer  "job_id",     null: false
    t.string   "reference",  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "buddy_id"
    t.datetime "started_at"
    t.datetime "deleted_at"
  end

  add_index "deploys", ["deleted_at"], name: "index_deploys_on_deleted_at", using: :btree
  add_index "deploys", ["job_id", "deleted_at"], name: "index_deploys_on_job_id_and_deleted_at", using: :btree
  add_index "deploys", ["stage_id", "deleted_at"], name: "index_deploys_on_stage_id_and_deleted_at", using: :btree

  create_table "environments", force: :cascade do |t|
    t.string   "name",                          null: false
    t.boolean  "is_production", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.string   "permalink",                     null: false
  end

  add_index "environments", ["permalink"], name: "index_environments_on_permalink", unique: true

  create_table "flowdock_flows", force: true do |t|
    t.string   "name",       null: false
    t.string   "token",      null: false
    t.integer  "stage_id",   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "guides", force: :cascade do |t|
    t.integer  "project_id", limit: 4
    t.text     "body",       limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "guides", ["project_id"], name: "index_guides_on_project_id", using: :btree

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
  add_index "jobs", ["status"], name: "index_jobs_on_status", using: :btree

  create_table "locks", force: true do |t|
    t.integer  "stage_id"
    t.integer  "user_id",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "description"
    t.boolean  "warning",     default: false, null: false
  end

  add_index "locks", ["stage_id", "deleted_at", "user_id"], name: "index_locks_on_stage_id_and_deleted_at_and_user_id", using: :btree

  create_table "macro_commands", force: true do |t|
    t.integer  "macro_id"
    t.integer  "command_id"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "macros", force: true do |t|
    t.string   "name",       null: false
    t.string   "reference",  null: false
    t.text     "command",    null: false
    t.integer  "project_id"
    t.integer  "user_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "macros", ["project_id", "deleted_at"], name: "index_macros_on_project_id_and_deleted_at", using: :btree

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
    t.string   "permalink",      null: false
    t.text     "description",    limit: 65535
    t.string   "owner",          limit: 255
  end

  add_index "projects", ["permalink", "deleted_at"], name: "index_projects_on_permalink_and_deleted_at", using: :btree
  add_index "projects", ["token", "deleted_at"], name: "index_projects_on_token_and_deleted_at", using: :btree

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
    t.boolean  "comment_on_zendesk_tickets"
    t.boolean  "production",                  default: false
    t.boolean  "use_github_deployment_api"
    t.string   "permalink",                                   null: false
    t.text     "dashboard",                   limit: 65535
    t.boolean  "email_committers_on_automated_deploy_failure",         default: false, null: false
    t.string   "static_emails_on_automated_deploy_failure", limit: 255
    t.string   "datadog_monitor_ids",                          limit: 255
  end

  add_index "stages", ["project_id", "permalink", "deleted_at"], name: "index_stages_on_project_id_and_permalink_and_deleted_at", using: :btree

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
    t.integer  "role_id",        default: 0,     null: false
    t.string   "token"
    t.datetime "deleted_at"
    t.string   "external_id"
    t.boolean  "desktop_notify", default: false
    t.boolean  "integration",    default: false, null: false
  end

  add_index "users", ["external_id", "deleted_at"], name: "index_users_on_external_id_and_deleted_at", using: :btree

  create_table "webhooks", force: true do |t|
    t.integer  "project_id", null: false
    t.integer  "stage_id",   null: false
    t.string   "branch",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
  end

  add_index "webhooks", ["project_id", "branch"], name: "index_webhooks_on_project_id_and_branch", using: :btree
  add_index "webhooks", ["stage_id", "branch"], name: "index_webhooks_on_stage_id_and_branch", using: :btree

end
