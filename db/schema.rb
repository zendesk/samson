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

ActiveRecord::Schema.define(version: 20150511231229) do

  create_table "build_statuses", force: :cascade do |t|
    t.integer  "build_id",                                     null: false
    t.string   "source",     limit: 255
    t.string   "status",     limit: 255,   default: "pending", null: false
    t.string   "url",        limit: 255
    t.string   "summary",    limit: 512
    t.text     "data",       limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "build_statuses", ["build_id"], name: "index_build_statuses_on_build_id", using: :btree

  create_table "builds", force: :cascade do |t|
    t.integer  "project_id",                       null: false
    t.integer  "number",              limit: 4
    t.string   "git_sha",             limit: 255
    t.string   "git_ref",             limit: 255
    t.string   "docker_image_id",     limit: 255
    t.string   "docker_ref",          limit: 255
    t.string   "docker_repo_digest",  limit: 255
    t.integer  "docker_build_job_id"
    t.string   "label",               limit: 255
    t.string   "description",         limit: 1024
    t.integer  "created_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "builds", ["created_by"], name: "index_builds_on_created_by", using: :btree
  add_index "builds", ["git_sha"], name: "index_builds_on_git_sha", unique: true, using: :btree
  add_index "builds", ["project_id"], name: "index_builds_on_project_id", using: :btree

  create_table "commands", force: :cascade do |t|
    t.text     "command",    limit: 10485760
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "project_id", limit: 4
  end

  create_table "deploy_groups", force: :cascade do |t|
    t.string   "name",           limit: 255, null: false
    t.integer  "environment_id", limit: 4,   null: false
    t.datetime "deleted_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "env_value",      limit: 255, null: false
  end

  add_index "deploy_groups", ["environment_id"], name: "index_deploy_groups_on_environment_id", using: :btree

  create_table "deploy_groups_stages", id: false, force: :cascade do |t|
    t.integer "deploy_group_id", limit: 4
    t.integer "stage_id",        limit: 4
  end

  add_index "deploy_groups_stages", ["deploy_group_id"], name: "index_deploy_groups_stages_on_deploy_group_id", using: :btree
  add_index "deploy_groups_stages", ["stage_id"], name: "index_deploy_groups_stages_on_stage_id", using: :btree

  create_table "deploys", force: :cascade do |t|
    t.integer  "stage_id",   limit: 4,   null: false
    t.integer  "job_id",     limit: 4,   null: false
    t.string   "reference",  limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "buddy_id",   limit: 4
    t.datetime "started_at"
    t.datetime "deleted_at"
    t.integer  "build_id",   limit: 4
  end

  add_index "deploys", ["build_id"], name: "index_deploys_on_build_id", using: :btree
  add_index "deploys", ["deleted_at"], name: "index_deploys_on_deleted_at", using: :btree
  add_index "deploys", ["job_id", "deleted_at"], name: "index_deploys_on_job_id_and_deleted_at", using: :btree
  add_index "deploys", ["stage_id", "deleted_at"], name: "index_deploys_on_stage_id_and_deleted_at", using: :btree

  create_table "environment_variable_groups", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.text   "comment", limit: 65535
  end

  add_index "environment_variable_groups", ["name"], name: "index_environment_variable_groups_on_name", unique: true, length: {"name"=>191}, using: :btree

  create_table "environment_variables", force: :cascade do |t|
    t.string  "name",        limit: 255, null: false
    t.string  "value",       limit: 255, null: false
    t.integer "parent_id",   limit: 4,   null: false
    t.string  "parent_type", limit: 255, null: false
    t.integer "scope_id",    limit: 4
    t.string  "scope_type",  limit: 255
  end

  add_index "environment_variables", ["parent_id", "parent_type", "name", "scope_type", "scope_id"], name: "environment_variables_unique_scope", unique: true, length: {"parent_id"=>nil, "parent_type"=>191, "name"=>191, "scope_type"=>191, "scope_id"=>nil}, using: :btree

  create_table "environments", force: :cascade do |t|
    t.string   "name",          limit: 255,                 null: false
    t.boolean  "is_production", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.string   "permalink",     limit: 255,                 null: false
  end

  add_index "environments", ["permalink"], name: "index_environments_on_permalink", unique: true, length: {"permalink"=>191}, using: :btree

  create_table "flowdock_flows", force: :cascade do |t|
    t.string   "name",       limit: 255,                null: false
    t.string   "token",      limit: 255,                null: false
    t.integer  "stage_id",   limit: 4,                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "enabled",    default: true
  end

  create_table "jenkins_jobs", force: :cascade do |t|
    t.integer  "jenkins_job_id", limit: 4
    t.string   "name",           limit: 255, null: false
    t.string   "status",         limit: 255
    t.string   "error",          limit: 255
    t.integer  "deploy_id",      limit: 4,   null: false
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "url",            limit: 255
  end

  add_index "jenkins_jobs", ["deploy_id"], name: "index_jenkins_jobs_on_deploy_id", using: :btree
  add_index "jenkins_jobs", ["jenkins_job_id"], name: "index_jenkins_jobs_on_jenkins_job_id", using: :btree

  create_table "jobs", force: :cascade do |t|
    t.text     "command",    limit: 65535,                          null: false
    t.integer  "user_id",    limit: 4,                              null: false
    t.integer  "project_id", limit: 4,                              null: false
    t.string   "status",     limit: 255,        default: "pending"
    t.text     "output",     limit: 1073741823
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "commit",     limit: 255
    t.string   "tag",        limit: 255
  end

  add_index "jobs", ["project_id"], name: "index_jobs_on_project_id", using: :btree
  add_index "jobs", ["status"], name: "index_jobs_on_status", length: {"status"=>191}, using: :btree

  create_table "locks", force: :cascade do |t|
    t.integer  "stage_id",    limit: 4
    t.integer  "user_id",     limit: 4,                   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "description", limit: 255
    t.boolean  "warning",     default: false, null: false
  end

  add_index "locks", ["stage_id", "deleted_at", "user_id"], name: "index_locks_on_stage_id_and_deleted_at_and_user_id", using: :btree

  create_table "macro_commands", force: :cascade do |t|
    t.integer  "macro_id",   limit: 4
    t.integer  "command_id", limit: 4
    t.integer  "position",   limit: 4, default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "macros", force: :cascade do |t|
    t.string   "name",       limit: 255,   null: false
    t.string   "reference",  limit: 255,   null: false
    t.text     "command",    limit: 65535, null: false
    t.integer  "project_id", limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "macros", ["project_id", "deleted_at"], name: "index_macros_on_project_id_and_deleted_at", using: :btree

  create_table "new_relic_applications", force: :cascade do |t|
    t.string  "name",     limit: 255
    t.integer "stage_id", limit: 4
  end

  add_index "new_relic_applications", ["stage_id", "name"], name: "index_new_relic_applications_on_stage_id_and_name", unique: true, length: {"stage_id"=>nil, "name"=>191}, using: :btree

  create_table "project_environment_variable_groups", force: :cascade do |t|
    t.integer "project_id",                    limit: 4, null: false
    t.integer "environment_variable_group_id", limit: 4, null: false
  end

  add_index "project_environment_variable_groups", ["environment_variable_group_id"], name: "project_environment_variable_groups_group_id", using: :btree
  add_index "project_environment_variable_groups", ["project_id", "environment_variable_group_id"], name: "project_environment_variable_groups_unique_group_id", unique: true, using: :btree

  create_table "projects", force: :cascade do |t|
    t.string   "name",               limit: 255,                   null: false
    t.string   "repository_url",     limit: 255,                   null: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "token",              limit: 255
    t.string   "release_branch",     limit: 255
    t.string   "permalink",          limit: 255,                   null: false
    t.text     "description",        limit: 65535
    t.string   "owner",              limit: 255
    t.boolean  "deploy_with_docker",               default: false, null: false
    t.boolean  "auto_release_docker_image",        default: false, null: false
  end

  add_index "projects", ["permalink", "deleted_at"], name: "index_projects_on_permalink_and_deleted_at", length: {"permalink"=>191, "deleted_at"=>nil}, using: :btree
  add_index "projects", ["token", "deleted_at"], name: "index_projects_on_token_and_deleted_at", length: {"token"=>191, "deleted_at"=>nil}, using: :btree

  create_table "releases", force: :cascade do |t|
    t.integer  "project_id",  limit: 4,               null: false
    t.string   "commit",      limit: 255,             null: false
    t.integer  "number",      limit: 4,   default: 1
    t.integer  "author_id",   limit: 4,               null: false
    t.string   "author_type", limit: 255,             null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "build_id",    limit: 4
  end

  add_index "releases", ["build_id"], name: "index_releases_on_build_id", using: :btree
  add_index "releases", ["project_id", "number"], name: "index_releases_on_project_id_and_number", unique: true, using: :btree

  create_table "slack_channels", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.string   "channel_id", limit: 255, null: false
    t.integer  "stage_id",   limit: 4,   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "slack_channels", ["stage_id"], name: "index_slack_channels_on_stage_id", using: :btree

  create_table "stage_commands", force: :cascade do |t|
    t.integer  "stage_id",   limit: 4
    t.integer  "command_id", limit: 4
    t.integer  "position",   limit: 4, default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stages", force: :cascade do |t|
    t.string   "name",                                         limit: 255,                   null: false
    t.integer  "project_id",                                   limit: 4,                     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notify_email_address",                         limit: 255
    t.integer  "order",                                        limit: 4
    t.datetime "deleted_at"
    t.boolean  "confirm",                                      default: true
    t.string   "datadog_tags",                                 limit: 255
    t.boolean  "update_github_pull_requests"
    t.boolean  "deploy_on_release",                            default: false
    t.boolean  "comment_on_zendesk_tickets"
    t.boolean  "production",                                   default: false
    t.boolean  "use_github_deployment_api"
    t.string   "permalink",                                    limit: 255,                   null: false
    t.text     "dashboard",                                    limit: 65535
    t.boolean  "email_committers_on_automated_deploy_failure", default: false, null: false
    t.string   "static_emails_on_automated_deploy_failure",    limit: 255
    t.string   "datadog_monitor_ids",                          limit: 255
    t.string   "jenkins_job_names",                            limit: 255
    t.string   "next_stage_ids"
  end

  add_index "stages", ["project_id", "permalink", "deleted_at"], name: "index_stages_on_project_id_and_permalink_and_deleted_at", length: {"project_id"=>nil, "permalink"=>191, "deleted_at"=>nil}, using: :btree

  create_table "stars", force: :cascade do |t|
    t.integer  "user_id",    limit: 4, null: false
    t.integer  "project_id", limit: 4, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "stars", ["user_id", "project_id"], name: "index_stars_on_user_id_and_project_id", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "name",           limit: 255,                 null: false
    t.string   "email",          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_id",        limit: 4,   default: 0,     null: false
    t.string   "token",          limit: 255
    t.datetime "deleted_at"
    t.string   "external_id",    limit: 255
    t.boolean  "desktop_notify", default: false
    t.boolean  "integration",    default: false, null: false
  end

  add_index "users", ["external_id", "deleted_at"], name: "index_users_on_external_id_and_deleted_at", length: {"external_id"=>191, "deleted_at"=>nil}, using: :btree

  create_table "webhooks", force: :cascade do |t|
    t.integer  "project_id", limit: 4,   null: false
    t.integer  "stage_id",   limit: 4,   null: false
    t.string   "branch",     limit: 255, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "source",     limit: 255, null: false
  end

  add_index "webhooks", ["project_id", "branch"], name: "index_webhooks_on_project_id_and_branch", length: {"project_id"=>nil, "branch"=>191}, using: :btree
  add_index "webhooks", ["stage_id", "branch"], name: "index_webhooks_on_stage_id_and_branch", length: {"stage_id"=>nil, "branch"=>191}, using: :btree

  add_foreign_key "deploy_groups", "environments"
end
