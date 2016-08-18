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

ActiveRecord::Schema.define(version: 20160818210955) do

  create_table "builds", force: :cascade do |t|
    t.integer  "project_id",                                       null: false
    t.string   "git_sha",             limit: 128,                  null: false
    t.string   "git_ref",                                          null: false
    t.string   "docker_image_id",     limit: 128
    t.string   "docker_ref"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "docker_repo_digest"
    t.integer  "docker_build_job_id"
    t.string   "label"
    t.string   "description",         limit: 1024
    t.integer  "created_by"
    t.integer  "number"
    t.boolean  "kubernetes_job",                   default: false, null: false
  end

  add_index "builds", ["created_by"], name: "index_builds_on_created_by"
  add_index "builds", ["git_sha"], name: "index_builds_on_git_sha", unique: true
  add_index "builds", ["project_id"], name: "index_builds_on_project_id"

  create_table "commands", force: :cascade do |t|
    t.text     "command",    limit: 2621440
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "project_id"
  end

  create_table "csv_exports", force: :cascade do |t|
    t.integer  "user_id",                        null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "filters",    default: "{}",      null: false
    t.string   "status",     default: "pending", null: false
  end

  create_table "deploy_groups", force: :cascade do |t|
    t.string   "name",           null: false
    t.integer  "environment_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "env_value",      null: false
    t.string   "permalink",      null: false
    t.string   "vault_instance"
  end

  add_index "deploy_groups", ["environment_id"], name: "index_deploy_groups_on_environment_id"
  add_index "deploy_groups", ["permalink"], name: "index_deploy_groups_on_permalink", unique: true

  create_table "deploy_groups_stages", id: false, force: :cascade do |t|
    t.integer "deploy_group_id"
    t.integer "stage_id"
  end

  add_index "deploy_groups_stages", ["deploy_group_id"], name: "index_deploy_groups_stages_on_deploy_group_id"
  add_index "deploy_groups_stages", ["stage_id"], name: "index_deploy_groups_stages_on_stage_id"

  create_table "deploy_response_urls", force: :cascade do |t|
    t.integer  "deploy_id",    null: false
    t.string   "response_url", null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "deploy_response_urls", ["deploy_id"], name: "index_deploy_response_urls_on_deploy_id", unique: true

  create_table "deploys", force: :cascade do |t|
    t.integer  "stage_id",                   null: false
    t.integer  "job_id",                     null: false
    t.string   "reference",                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "buddy_id"
    t.datetime "started_at"
    t.datetime "deleted_at"
    t.integer  "build_id"
    t.boolean  "release",    default: false, null: false
    t.boolean  "kubernetes", default: false, null: false
  end

  add_index "deploys", ["build_id"], name: "index_deploys_on_build_id"
  add_index "deploys", ["deleted_at"], name: "index_deploys_on_deleted_at"
  add_index "deploys", ["job_id", "deleted_at"], name: "index_deploys_on_job_id_and_deleted_at"
  add_index "deploys", ["stage_id", "deleted_at"], name: "index_deploys_on_stage_id_and_deleted_at"

  create_table "environment_variable_groups", force: :cascade do |t|
    t.string "name",    null: false
    t.text   "comment"
  end

  add_index "environment_variable_groups", ["name"], name: "index_environment_variable_groups_on_name", unique: true

  create_table "environment_variables", force: :cascade do |t|
    t.string  "name",        null: false
    t.string  "value",       null: false
    t.integer "parent_id",   null: false
    t.string  "parent_type", null: false
    t.integer "scope_id"
    t.string  "scope_type"
  end

  add_index "environment_variables", ["parent_id", "parent_type", "name", "scope_type", "scope_id"], name: "environment_variables_unique_scope", unique: true

  create_table "environments", force: :cascade do |t|
    t.string   "name",                       null: false
    t.boolean  "production", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "permalink",                  null: false
  end

  add_index "environments", ["permalink"], name: "index_environments_on_permalink", unique: true

  create_table "flowdock_flows", force: :cascade do |t|
    t.string   "name",                      null: false
    t.string   "token",                     null: false
    t.integer  "stage_id",                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "enabled",    default: true
  end

  create_table "jenkins_jobs", force: :cascade do |t|
    t.integer  "jenkins_job_id"
    t.string   "name",           null: false
    t.string   "status"
    t.string   "error"
    t.integer  "deploy_id",      null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "url"
  end

  add_index "jenkins_jobs", ["deploy_id"], name: "index_jenkins_jobs_on_deploy_id"
  add_index "jenkins_jobs", ["jenkins_job_id"], name: "index_jenkins_jobs_on_jenkins_job_id"

  create_table "jobs", force: :cascade do |t|
    t.text     "command",                                          null: false
    t.integer  "user_id",                                          null: false
    t.integer  "project_id",                                       null: false
    t.string   "status",                       default: "pending"
    t.text     "output",     limit: 268435455
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "commit"
    t.string   "tag"
  end

  add_index "jobs", ["project_id"], name: "index_jobs_on_project_id"
  add_index "jobs", ["status"], name: "index_jobs_on_status"

  create_table "kubernetes_cluster_deploy_groups", force: :cascade do |t|
    t.integer  "kubernetes_cluster_id", null: false
    t.integer  "deploy_group_id",       null: false
    t.string   "namespace",             null: false
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "kubernetes_cluster_deploy_groups", ["deploy_group_id"], name: "index_kubernetes_cluster_deploy_groups_on_deploy_group_id"
  add_index "kubernetes_cluster_deploy_groups", ["kubernetes_cluster_id"], name: "index_kuber_cluster_deploy_groups_on_kuber_cluster_id"

  create_table "kubernetes_clusters", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.string   "config_filepath"
    t.string   "config_context"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "kubernetes_deploy_group_roles", force: :cascade do |t|
    t.integer "project_id",                                 null: false
    t.integer "deploy_group_id",                            null: false
    t.integer "replicas",                                   null: false
    t.integer "ram",                                        null: false
    t.decimal "cpu",                precision: 4, scale: 2, null: false
    t.integer "kubernetes_role_id",                         null: false
  end

  add_index "kubernetes_deploy_group_roles", ["deploy_group_id"], name: "index_kubernetes_deploy_group_roles_on_deploy_group_id"
  add_index "kubernetes_deploy_group_roles", ["project_id", "deploy_group_id", "kubernetes_role_id"], name: "index_kubernetes_deploy_group_roles_on_project_id"

  create_table "kubernetes_release_docs", force: :cascade do |t|
    t.integer  "kubernetes_role_id",                            null: false
    t.integer  "kubernetes_release_id",                         null: false
    t.integer  "replica_target",                                null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "deploy_group_id"
    t.decimal  "cpu",                   precision: 4, scale: 2, null: false
    t.integer  "ram",                                           null: false
    t.text     "resource_template"
  end

  add_index "kubernetes_release_docs", ["kubernetes_release_id"], name: "index_kubernetes_release_docs_on_kubernetes_release_id"
  add_index "kubernetes_release_docs", ["kubernetes_role_id"], name: "index_kubernetes_release_docs_on_kubernetes_role_id"

  create_table "kubernetes_releases", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "build_id"
    t.integer  "user_id"
    t.integer  "project_id",            null: false
    t.integer  "deploy_id"
    t.string   "git_sha",    limit: 40, null: false
    t.string   "git_ref"
  end

  add_index "kubernetes_releases", ["build_id"], name: "index_kubernetes_releases_on_build_id"

  create_table "kubernetes_roles", force: :cascade do |t|
    t.integer  "project_id",    null: false
    t.string   "name",          null: false
    t.string   "config_file"
    t.string   "service_name"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.datetime "deleted_at"
    t.string   "resource_name", null: false
  end

  add_index "kubernetes_roles", ["project_id"], name: "index_kubernetes_roles_on_project_id"
  add_index "kubernetes_roles", ["resource_name", "deleted_at"], name: "index_kubernetes_roles_on_resource_name_and_deleted_at", unique: true
  add_index "kubernetes_roles", ["service_name", "deleted_at"], name: "index_kubernetes_roles_on_service_name_and_deleted_at", unique: true

  create_table "locks", force: :cascade do |t|
    t.integer  "stage_id"
    t.integer  "user_id",                     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "description"
    t.boolean  "warning",     default: false, null: false
    t.datetime "delete_at"
  end

  add_index "locks", ["stage_id", "deleted_at", "user_id"], name: "index_locks_on_stage_id_and_deleted_at_and_user_id"

  create_table "macro_commands", force: :cascade do |t|
    t.integer  "macro_id"
    t.integer  "command_id"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "macros", force: :cascade do |t|
    t.string   "name",       null: false
    t.string   "reference",  null: false
    t.integer  "project_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "macros", ["project_id", "deleted_at"], name: "index_macros_on_project_id_and_deleted_at"

  create_table "new_relic_applications", force: :cascade do |t|
    t.string  "name"
    t.integer "stage_id"
  end

  add_index "new_relic_applications", ["stage_id", "name"], name: "index_new_relic_applications_on_stage_id_and_name", unique: true

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id", null: false
    t.integer  "application_id",    null: false
    t.string   "token",             null: false
    t.integer  "expires_in",        null: false
    t.text     "redirect_uri",      null: false
    t.datetime "created_at",        null: false
    t.datetime "revoked_at"
    t.string   "scopes"
  end

  add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id"
    t.string   "token",                               null: false
    t.string   "refresh_token"
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",                          null: false
    t.string   "scopes"
    t.string   "previous_refresh_token", default: "", null: false
  end

  add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
  add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
  add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",                      null: false
    t.string   "uid",                       null: false
    t.string   "secret",                    null: false
    t.text     "redirect_uri",              null: false
    t.string   "scopes",       default: "", null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true

  create_table "outbound_webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.integer  "project_id"
    t.integer  "stage_id"
    t.string   "url"
    t.string   "username"
    t.string   "password"
  end

  add_index "outbound_webhooks", ["deleted_at"], name: "index_outbound_webhooks_on_deleted_at"

  create_table "project_environment_variable_groups", force: :cascade do |t|
    t.integer "project_id",                    null: false
    t.integer "environment_variable_group_id", null: false
  end

  add_index "project_environment_variable_groups", ["environment_variable_group_id"], name: "project_environment_variable_groups_group_id"
  add_index "project_environment_variable_groups", ["project_id", "environment_variable_group_id"], name: "project_environment_variable_groups_unique_group_id", unique: true

  create_table "projects", force: :cascade do |t|
    t.string   "name",                                                    null: false
    t.string   "repository_url",                                          null: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "token"
    t.string   "release_branch"
    t.string   "permalink",                                               null: false
    t.text     "description",               limit: 65535
    t.string   "owner",                     limit: 255
    t.boolean  "deploy_with_docker",                      default: false, null: false
    t.boolean  "auto_release_docker_image",               default: false, null: false
  end

  add_index "projects", ["permalink", "deleted_at"], name: "index_projects_on_permalink_and_deleted_at"
  add_index "projects", ["token", "deleted_at"], name: "index_projects_on_token_and_deleted_at"

  create_table "releases", force: :cascade do |t|
    t.integer  "project_id",              null: false
    t.string   "commit",                  null: false
    t.integer  "number",      default: 1
    t.integer  "author_id",               null: false
    t.string   "author_type",             null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "build_id"
  end

  add_index "releases", ["build_id"], name: "index_releases_on_build_id"
  add_index "releases", ["project_id", "number"], name: "index_releases_on_project_id_and_number", unique: true

  create_table "secrets", id: false, force: :cascade do |t|
    t.string   "id"
    t.string   "encrypted_value",                    null: false
    t.string   "encrypted_value_iv",                 null: false
    t.string   "encryption_key_sha",                 null: false
    t.integer  "updater_id",                         null: false
    t.integer  "creator_id",                         null: false
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.boolean  "visible",            default: false, null: false
    t.string   "comment"
  end

  add_index "secrets", ["id"], name: "index_secrets_on_id", unique: true

  create_table "slack_identifiers", force: :cascade do |t|
    t.integer  "user_id"
    t.text     "identifier", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "slack_identifiers", ["identifier"], name: "index_slack_identifiers_on_identifier"
  add_index "slack_identifiers", ["user_id"], name: "index_slack_identifiers_on_user_id", unique: true

  create_table "slack_webhooks", force: :cascade do |t|
    t.text     "webhook_url",                   null: false
    t.string   "channel"
    t.integer  "stage_id",                      null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "before_deploy", default: false, null: false
    t.boolean  "after_deploy",  default: true,  null: false
    t.boolean  "for_buddy",     default: false, null: false
  end

  add_index "slack_webhooks", ["stage_id"], name: "index_slack_webhooks_on_stage_id"

  create_table "stage_commands", force: :cascade do |t|
    t.integer  "stage_id"
    t.integer  "command_id"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
  end

  create_table "stages", force: :cascade do |t|
    t.string   "name",                                                                       null: false
    t.integer  "project_id",                                                                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notify_email_address"
    t.integer  "order"
    t.datetime "deleted_at"
    t.boolean  "confirm",                                                    default: true
    t.string   "datadog_tags"
    t.boolean  "update_github_pull_requests"
    t.boolean  "deploy_on_release",                                          default: false
    t.boolean  "comment_on_zendesk_tickets"
    t.boolean  "production",                                                 default: false
    t.boolean  "use_github_deployment_api"
    t.string   "permalink",                                                                  null: false
    t.text     "dashboard",                                    limit: 65535
    t.boolean  "email_committers_on_automated_deploy_failure",               default: false, null: false
    t.string   "static_emails_on_automated_deploy_failure",    limit: 255
    t.string   "datadog_monitor_ids",                          limit: 255
    t.string   "jenkins_job_names"
    t.string   "next_stage_ids"
    t.boolean  "no_code_deployed",                                           default: false
    t.boolean  "docker_binary_plugin_enabled",                               default: true
    t.boolean  "kubernetes",                                                 default: false, null: false
  end

  add_index "stages", ["project_id", "permalink", "deleted_at"], name: "index_stages_on_project_id_and_permalink_and_deleted_at"

  create_table "stars", force: :cascade do |t|
    t.integer  "user_id",    null: false
    t.integer  "project_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "stars", ["user_id", "project_id"], name: "index_stars_on_user_id_and_project_id", unique: true

  create_table "user_project_roles", force: :cascade do |t|
    t.integer  "project_id", null: false
    t.integer  "user_id",    null: false
    t.integer  "role_id",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "user_project_roles", ["project_id"], name: "index_user_project_roles_on_project_id"
  add_index "user_project_roles", ["user_id", "project_id"], name: "index_user_project_roles_on_user_id_and_project_id", unique: true

  create_table "users", force: :cascade do |t|
    t.string   "name",                                        null: false
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_id",                default: 0,          null: false
    t.string   "token"
    t.datetime "deleted_at"
    t.string   "external_id"
    t.boolean  "desktop_notify",         default: false
    t.boolean  "integration",            default: false,      null: false
    t.boolean  "access_request_pending", default: false
    t.string   "time_format",            default: "relative", null: false
  end

  add_index "users", ["external_id", "deleted_at"], name: "index_users_on_external_id_and_deleted_at"

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",                     null: false
    t.integer  "item_id",                       null: false
    t.string   "event",                         null: false
    t.string   "whodunnit"
    t.text     "object",     limit: 1073741823
    t.datetime "created_at"
  end

  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"

  create_table "webhooks", force: :cascade do |t|
    t.integer  "project_id", null: false
    t.integer  "stage_id",   null: false
    t.string   "branch",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "source",     null: false
  end

  add_index "webhooks", ["project_id", "branch"], name: "index_webhooks_on_project_id_and_branch"
  add_index "webhooks", ["stage_id", "branch"], name: "index_webhooks_on_stage_id_and_branch"

end
