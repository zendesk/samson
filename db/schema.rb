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

ActiveRecord::Schema.define(version: 20170208221802) do

  create_table "builds", force: :cascade do |t|
    t.integer  "project_id",                                       null: false
    t.integer  "number"
    t.string   "git_sha",                                          null: false
    t.string   "git_ref",                                          null: false
    t.string   "docker_image_id"
    t.string   "docker_tag"
    t.string   "docker_repo_digest"
    t.integer  "docker_build_job_id"
    t.string   "label"
    t.string   "description",         limit: 1024
    t.integer  "created_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "kubernetes_job",                   default: false, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "source_url"
    t.index ["created_by"], name: "index_builds_on_created_by", using: :btree
    t.index ["git_sha"], name: "index_builds_on_git_sha", unique: true, using: :btree
    t.index ["project_id"], name: "index_builds_on_project_id", using: :btree
  end

  create_table "commands", force: :cascade do |t|
    t.text     "command",    limit: 10485760
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
    t.string   "name",            null: false
    t.integer  "environment_id",  null: false
    t.datetime "deleted_at"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.string   "env_value",       null: false
    t.string   "permalink",       null: false
    t.integer  "vault_server_id"
    t.index ["environment_id"], name: "index_deploy_groups_on_environment_id", using: :btree
    t.index ["permalink"], name: "index_deploy_groups_on_permalink", unique: true, length: { permalink: 191 }, using: :btree
  end

  create_table "deploy_groups_stages", id: false, force: :cascade do |t|
    t.integer "deploy_group_id"
    t.integer "stage_id"
    t.index ["deploy_group_id"], name: "index_deploy_groups_stages_on_deploy_group_id", using: :btree
    t.index ["stage_id"], name: "index_deploy_groups_stages_on_stage_id", using: :btree
  end

  create_table "deploy_response_urls", force: :cascade do |t|
    t.integer  "deploy_id",    null: false
    t.string   "response_url", null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.index ["deploy_id"], name: "index_deploy_response_urls_on_deploy_id", unique: true, using: :btree
  end

  create_table "deploys", force: :cascade do |t|
    t.integer  "stage_id",                               null: false
    t.integer  "job_id",                                 null: false
    t.string   "reference",                              null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "buddy_id"
    t.datetime "started_at"
    t.datetime "deleted_at"
    t.integer  "build_id"
    t.boolean  "release",                default: false, null: false
    t.boolean  "kubernetes",             default: false, null: false
    t.integer  "project_id",                             null: false
    t.boolean  "kubernetes_rollback",    default: true,  null: false
    t.boolean  "kubernetes_reuse_build", default: false, null: false
    t.index ["build_id"], name: "index_deploys_on_build_id", using: :btree
    t.index ["deleted_at"], name: "index_deploys_on_deleted_at", using: :btree
    t.index ["job_id", "deleted_at"], name: "index_deploys_on_job_id_and_deleted_at", using: :btree
    t.index ["project_id", "deleted_at"], name: "index_deploys_on_project_id_and_deleted_at", using: :btree
    t.index ["stage_id", "deleted_at"], name: "index_deploys_on_stage_id_and_deleted_at", using: :btree
  end

  create_table "environment_variable_groups", force: :cascade do |t|
    t.string "name",                  null: false
    t.text   "comment", limit: 65535
    t.index ["name"], name: "index_environment_variable_groups_on_name", unique: true, length: { name: 191 }, using: :btree
  end

  create_table "environment_variables", force: :cascade do |t|
    t.string  "name",        null: false
    t.string  "value",       null: false
    t.integer "parent_id",   null: false
    t.string  "parent_type", null: false
    t.integer "scope_id"
    t.string  "scope_type"
    t.index ["parent_id", "parent_type", "name", "scope_type", "scope_id"], name: "environment_variables_unique_scope", unique: true, length: { parent_type: 191, name: 191, scope_type: 191 }, using: :btree
  end

  create_table "environments", force: :cascade do |t|
    t.string   "name",                       null: false
    t.boolean  "production", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "permalink",                  null: false
    t.index ["permalink"], name: "index_environments_on_permalink", unique: true, length: { permalink: 191 }, using: :btree
  end

  create_table "flowdock_flows", force: :cascade do |t|
    t.string   "name",                      null: false
    t.string   "token",                     null: false
    t.integer  "stage_id",                  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "enabled",    default: true, null: false
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
    t.index ["deploy_id"], name: "index_jenkins_jobs_on_deploy_id", using: :btree
    t.index ["jenkins_job_id"], name: "index_jenkins_jobs_on_jenkins_job_id", using: :btree
  end

  create_table "jobs", force: :cascade do |t|
    t.text     "command",    limit: 65535,                          null: false
    t.integer  "user_id",                                           null: false
    t.integer  "project_id",                                        null: false
    t.string   "status",                        default: "pending"
    t.text     "output",     limit: 1073741823
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "commit"
    t.string   "tag"
    t.index ["project_id"], name: "index_jobs_on_project_id", using: :btree
    t.index ["status"], name: "index_jobs_on_status", length: { status: 191 }, using: :btree
    t.index ["user_id"], name: "index_jobs_on_user_id", using: :btree
  end

  create_table "kubernetes_cluster_deploy_groups", force: :cascade do |t|
    t.integer  "kubernetes_cluster_id", null: false
    t.integer  "deploy_group_id",       null: false
    t.string   "namespace",             null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["deploy_group_id"], name: "index_kubernetes_cluster_deploy_groups_on_deploy_group_id", using: :btree
    t.index ["kubernetes_cluster_id"], name: "index_kuber_cluster_deploy_groups_on_kuber_cluster_id", using: :btree
  end

  create_table "kubernetes_clusters", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "config_filepath"
    t.string   "config_context"
    t.string   "ip_prefix"
  end

  create_table "kubernetes_deploy_group_roles", force: :cascade do |t|
    t.integer "project_id",                                 null: false
    t.integer "deploy_group_id",                            null: false
    t.integer "replicas",                                   null: false
    t.integer "ram",                                        null: false
    t.decimal "cpu",                precision: 4, scale: 2, null: false
    t.integer "kubernetes_role_id",                         null: false
    t.index ["deploy_group_id"], name: "index_kubernetes_deploy_group_roles_on_deploy_group_id", using: :btree
    t.index ["project_id", "deploy_group_id", "kubernetes_role_id"], name: "index_kubernetes_deploy_group_roles_on_project_id", using: :btree
  end

  create_table "kubernetes_release_docs", force: :cascade do |t|
    t.integer  "kubernetes_role_id",                                          null: false
    t.integer  "kubernetes_release_id",                                       null: false
    t.integer  "replica_target",                                              null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "deploy_group_id"
    t.decimal  "cpu",                                 precision: 4, scale: 2, null: false
    t.integer  "ram",                                                         null: false
    t.text     "resource_template",     limit: 65535
    t.index ["kubernetes_release_id"], name: "index_kubernetes_release_docs_on_kubernetes_release_id", using: :btree
    t.index ["kubernetes_role_id"], name: "index_kubernetes_release_docs_on_kubernetes_role_id", using: :btree
  end

  create_table "kubernetes_releases", force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "build_id"
    t.integer  "user_id"
    t.integer  "project_id",            null: false
    t.integer  "deploy_id"
    t.string   "git_sha",    limit: 40, null: false
    t.string   "git_ref",               null: false
    t.index ["build_id"], name: "index_kubernetes_releases_on_build_id", using: :btree
  end

  create_table "kubernetes_roles", force: :cascade do |t|
    t.integer  "project_id",    null: false
    t.string   "name",          null: false
    t.string   "config_file"
    t.string   "service_name"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.datetime "deleted_at"
    t.string   "resource_name", null: false
    t.index ["project_id"], name: "index_kubernetes_roles_on_project_id", using: :btree
    t.index ["resource_name", "deleted_at"], name: "index_kubernetes_roles_on_resource_name_and_deleted_at", unique: true, length: { resource_name: 191 }, using: :btree
    t.index ["service_name", "deleted_at"], name: "index_kubernetes_roles_on_service_name_and_deleted_at", unique: true, length: { service_name: 191 }, using: :btree
  end

  create_table "locks", force: :cascade do |t|
    t.integer  "resource_id"
    t.integer  "user_id",                                    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "description",   limit: 1024
    t.boolean  "warning",                    default: false, null: false
    t.datetime "delete_at"
    t.string   "resource_type"
    t.index ["resource_id", "resource_type", "deleted_at"], name: "index_locks_on_resource_id_and_resource_type_and_deleted_at", unique: true, length: { resource_type: 40 }, using: :btree
  end

  create_table "macro_commands", force: :cascade do |t|
    t.integer  "macro_id"
    t.integer  "command_id"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["command_id"], name: "index_macro_commands_on_command_id", using: :btree
    t.index ["macro_id"], name: "index_macro_commands_on_macro_id", using: :btree
  end

  create_table "macros", force: :cascade do |t|
    t.string   "name",       null: false
    t.string   "reference",  null: false
    t.integer  "project_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["project_id", "deleted_at"], name: "index_macros_on_project_id_and_deleted_at", using: :btree
  end

  create_table "new_relic_applications", force: :cascade do |t|
    t.string  "name"
    t.integer "stage_id"
    t.index ["stage_id", "name"], name: "index_new_relic_applications_on_stage_id_and_name", unique: true, length: { name: 191 }, using: :btree
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id",               null: false
    t.integer  "application_id",                  null: false
    t.string   "token",                           null: false
    t.integer  "expires_in",                      null: false
    t.text     "redirect_uri",      limit: 65535, null: false
    t.datetime "created_at",                      null: false
    t.datetime "revoked_at"
    t.string   "scopes"
    t.index ["application_id"], name: "fk_rails_b4b53e07b8", using: :btree
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true, length: { token: 191 }, using: :btree
  end

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
    t.string   "description"
    t.datetime "last_used_at"
    t.index ["application_id"], name: "fk_rails_732cb83ab7", using: :btree
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true, length: { refresh_token: 191 }, using: :btree
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id", using: :btree
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true, length: { token: 191 }, using: :btree
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",                                    null: false
    t.string   "uid",                                     null: false
    t.string   "secret",                                  null: false
    t.text     "redirect_uri", limit: 65535,              null: false
    t.string   "scopes",                     default: "", null: false
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true, length: { uid: 191 }, using: :btree
  end

  create_table "outbound_webhooks", force: :cascade do |t|
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.datetime "deleted_at"
    t.integer  "project_id", default: 0, null: false
    t.integer  "stage_id",   default: 0, null: false
    t.string   "url",                    null: false
    t.string   "username"
    t.string   "password"
    t.index ["deleted_at"], name: "index_outbound_webhooks_on_deleted_at", using: :btree
    t.index ["project_id"], name: "index_outbound_webhooks_on_project_id", using: :btree
  end

  create_table "project_environment_variable_groups", force: :cascade do |t|
    t.integer "project_id",                    null: false
    t.integer "environment_variable_group_id", null: false
    t.index ["environment_variable_group_id"], name: "project_environment_variable_groups_group_id", using: :btree
    t.index ["project_id", "environment_variable_group_id"], name: "project_environment_variable_groups_unique_group_id", unique: true, using: :btree
  end

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
    t.string   "owner"
    t.boolean  "include_new_deploy_groups",               default: false, null: false
    t.string   "docker_release_branch"
    t.string   "release_source",                          default: "any", null: false
    t.integer  "build_command_id"
    t.index ["build_command_id"], name: "index_projects_on_build_command_id", using: :btree
    t.index ["permalink"], name: "index_projects_on_permalink", unique: true, length: { permalink: 191 }, using: :btree
    t.index ["token"], name: "index_projects_on_token", unique: true, length: { token: 191 }, using: :btree
  end

  create_table "releases", force: :cascade do |t|
    t.integer  "project_id",                           null: false
    t.string   "commit",                               null: false
    t.string   "number",      limit: 20, default: "1", null: false
    t.integer  "author_id",                            null: false
    t.string   "author_type",                          null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "build_id"
    t.index ["build_id"], name: "index_releases_on_build_id", using: :btree
    t.index ["project_id", "number"], name: "index_releases_on_project_id_and_number", unique: true, using: :btree
  end

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
    t.index ["id"], name: "index_secrets_on_id", unique: true, length: { id: 191 }, using: :btree
  end

  create_table "slack_channels", force: :cascade do |t|
    t.string   "name",       null: false
    t.string   "channel_id", null: false
    t.integer  "stage_id",   null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["stage_id"], name: "index_slack_channels_on_stage_id", using: :btree
  end

  create_table "slack_identifiers", force: :cascade do |t|
    t.integer  "user_id"
    t.text     "identifier", limit: 65535, null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["identifier"], name: "index_slack_identifiers_on_identifier", length: { identifier: 12 }, using: :btree
    t.index ["user_id"], name: "index_slack_identifiers_on_user_id", unique: true, using: :btree
  end

  create_table "slack_webhooks", force: :cascade do |t|
    t.text     "webhook_url",     limit: 65535,                 null: false
    t.string   "channel"
    t.integer  "stage_id",                                      null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "before_deploy",                 default: false, null: false
    t.boolean  "after_deploy",                  default: true,  null: false
    t.boolean  "for_buddy",                     default: false, null: false
    t.boolean  "only_on_failure",               default: false, null: false
    t.index ["stage_id"], name: "index_slack_webhooks_on_stage_id", using: :btree
  end

  create_table "stage_commands", force: :cascade do |t|
    t.integer  "stage_id"
    t.integer  "command_id"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.index ["command_id"], name: "index_stage_commands_on_command_id", using: :btree
    t.index ["stage_id"], name: "index_stage_commands_on_stage_id", using: :btree
  end

  create_table "stages", force: :cascade do |t|
    t.string   "name",                                                                       null: false
    t.integer  "project_id",                                                                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "notify_email_address"
    t.integer  "order",                                                                      null: false
    t.datetime "deleted_at"
    t.boolean  "confirm",                                                    default: true,  null: false
    t.string   "datadog_tags"
    t.boolean  "update_github_pull_requests",                                default: false, null: false
    t.boolean  "deploy_on_release",                                          default: false, null: false
    t.boolean  "comment_on_zendesk_tickets",                                 default: false, null: false
    t.boolean  "production",                                                 default: false, null: false
    t.boolean  "use_github_deployment_api",                                  default: false, null: false
    t.string   "permalink",                                                                  null: false
    t.text     "dashboard",                                    limit: 65535
    t.boolean  "email_committers_on_automated_deploy_failure",               default: false, null: false
    t.string   "static_emails_on_automated_deploy_failure"
    t.string   "datadog_monitor_ids"
    t.string   "jenkins_job_names"
    t.string   "next_stage_ids"
    t.boolean  "no_code_deployed",                                           default: false, null: false
    t.boolean  "docker_binary_plugin_enabled",                               default: false, null: false
    t.boolean  "kubernetes",                                                 default: false, null: false
    t.boolean  "is_template",                                                default: false, null: false
    t.boolean  "notify_airbrake",                                            default: false, null: false
    t.integer  "template_stage_id"
    t.boolean  "jenkins_email_committers",                                   default: false, null: false
    t.boolean  "run_in_parallel",                                            default: false, null: false
    t.boolean  "jenkins_build_params",                                       default: false, null: false
    t.boolean  "cancel_queued_deploys",                                      default: false, null: false
    t.index ["project_id", "permalink"], name: "index_stages_on_project_id_and_permalink", unique: true, length: { permalink: 191 }, using: :btree
    t.index ["template_stage_id"], name: "index_stages_on_template_stage_id", using: :btree
  end

  create_table "stars", force: :cascade do |t|
    t.integer  "user_id",    null: false
    t.integer  "project_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id", "project_id"], name: "index_stars_on_user_id_and_project_id", unique: true, using: :btree
  end

  create_table "user_project_roles", force: :cascade do |t|
    t.integer  "project_id", null: false
    t.integer  "user_id",    null: false
    t.integer  "role_id",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["project_id"], name: "index_user_project_roles_on_project_id", using: :btree
    t.index ["user_id", "project_id"], name: "index_user_project_roles_on_user_id_and_project_id", unique: true, using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.string   "name",                                        null: false
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "role_id",                default: 0,          null: false
    t.string   "token"
    t.datetime "deleted_at"
    t.string   "external_id"
    t.boolean  "desktop_notify",         default: false,      null: false
    t.boolean  "integration",            default: false,      null: false
    t.boolean  "access_request_pending", default: false,      null: false
    t.string   "time_format",            default: "relative", null: false
    t.datetime "last_login_at"
    t.datetime "last_seen_at"
    t.index ["external_id", "deleted_at"], name: "index_users_on_external_id_and_deleted_at", length: { external_id: 191 }, using: :btree
  end

  create_table "vault_servers", force: :cascade do |t|
    t.string   "name",                                             null: false
    t.string   "address",                                          null: false
    t.string   "encrypted_token",                                  null: false
    t.string   "encrypted_token_iv",                               null: false
    t.string   "encryption_key_sha",                               null: false
    t.boolean  "tls_verify",                       default: false, null: false
    t.text     "ca_cert",            limit: 65535
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.index ["name"], name: "index_vault_servers_on_name", unique: true, length: { name: 191 }, using: :btree
  end

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",                     null: false
    t.integer  "item_id",                       null: false
    t.string   "event",                         null: false
    t.string   "whodunnit"
    t.text     "object",     limit: 1073741823
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", length: { item_type: 191 }, using: :btree
  end

  create_table "webhooks", force: :cascade do |t|
    t.integer  "project_id", null: false
    t.integer  "stage_id",   null: false
    t.string   "branch",     null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string   "source",     null: false
    t.index ["project_id", "branch"], name: "index_webhooks_on_project_id_and_branch", length: { branch: 191 }, using: :btree
    t.index ["stage_id", "branch"], name: "index_webhooks_on_stage_id_and_branch", length: { branch: 191 }, using: :btree
  end

  add_foreign_key "deploy_groups", "environments"
end
