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

ActiveRecord::Schema.define(version: 2019_05_14_231932) do

  create_table "audits" do |t|
    t.integer "auditable_id", null: false
    t.string "auditable_type", null: false
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action", null: false
    t.text "audited_changes", limit: 1073741823
    t.integer "version", default: 0, null: false
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at", null: false
    t.index ["associated_id", "associated_type"], name: "associated_index", length: { associated_type: 100 }
    t.index ["auditable_id", "auditable_type"], name: "auditable_index", length: { auditable_type: 100 }
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid", length: 100
    t.index ["user_id", "user_type"], name: "user_index", length: { user_type: 100 }
  end

  create_table "builds", id: :integer do |t|
    t.integer "project_id", null: false
    t.integer "number"
    t.string "git_sha", null: false
    t.string "git_ref", null: false
    t.string "docker_tag"
    t.string "docker_repo_digest"
    t.integer "docker_build_job_id"
    t.string "name"
    t.string "description", limit: 1024
    t.integer "created_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "external_url"
    t.string "dockerfile", default: "Dockerfile"
    t.string "external_status"
    t.string "image_name"
    t.index ["created_by"], name: "index_builds_on_created_by"
    t.index ["git_sha", "dockerfile"], name: "index_builds_on_git_sha_and_dockerfile", unique: true
    t.index ["git_sha", "image_name"], name: "index_builds_on_git_sha_and_image_name", unique: true, length: 80
    t.index ["project_id"], name: "index_builds_on_project_id"
  end

  create_table "commands", id: :integer do |t|
    t.text "command", limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "project_id"
  end

  create_table "csv_exports", id: :integer do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "filters", default: "{}", null: false
    t.string "status", default: "pending", null: false
  end

  create_table "deploy_groups", id: :integer do |t|
    t.string "name", null: false
    t.integer "environment_id", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "env_value", null: false
    t.string "permalink", null: false
    t.integer "vault_server_id"
    t.string "name_sortable", null: false
    t.index ["environment_id"], name: "index_deploy_groups_on_environment_id"
    t.index ["permalink"], name: "index_deploy_groups_on_permalink", unique: true, length: 191
  end

  create_table "deploy_groups_stages", id: false do |t|
    t.integer "deploy_group_id"
    t.integer "stage_id"
    t.index ["deploy_group_id"], name: "index_deploy_groups_stages_on_deploy_group_id"
    t.index ["stage_id"], name: "index_deploy_groups_stages_on_stage_id"
  end

  create_table "deploy_response_urls", id: :integer do |t|
    t.integer "deploy_id", null: false
    t.string "response_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deploy_id"], name: "index_deploy_response_urls_on_deploy_id", unique: true
  end

  create_table "deploys", id: :integer do |t|
    t.integer "stage_id", null: false
    t.integer "job_id", null: false
    t.string "reference", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "buddy_id"
    t.datetime "started_at"
    t.datetime "deleted_at"
    t.integer "build_id"
    t.boolean "release", default: false, null: false
    t.boolean "kubernetes", default: false, null: false
    t.integer "project_id", null: false
    t.boolean "kubernetes_rollback", default: true, null: false
    t.boolean "kubernetes_reuse_build", default: false, null: false
    t.text "env_state", limit: 16777215
    t.integer "triggering_deploy_id"
    t.boolean "redeploy_previous_when_failed", default: false, null: false
    t.index ["build_id"], name: "index_deploys_on_build_id"
    t.index ["deleted_at"], name: "index_deploys_on_deleted_at"
    t.index ["job_id", "deleted_at"], name: "index_deploys_on_job_id_and_deleted_at"
    t.index ["project_id", "deleted_at"], name: "index_deploys_on_project_id_and_deleted_at"
    t.index ["stage_id", "deleted_at"], name: "index_deploys_on_stage_id_and_deleted_at"
    t.index ["triggering_deploy_id"], name: "index_deploys_on_triggering_deploy_id"
  end

  create_table "environment_variable_groups", id: :integer do |t|
    t.string "name", null: false
    t.text "comment"
    t.index ["name"], name: "index_environment_variable_groups_on_name", unique: true
  end

  create_table "environment_variables", id: :integer do |t|
    t.string "name", null: false
    t.string "value", limit: 2048, null: false
    t.integer "parent_id", null: false
    t.string "parent_type", null: false
    t.integer "scope_id"
    t.string "scope_type"
    t.index ["parent_id", "parent_type", "name", "scope_type", "scope_id"], name: "environment_variables_unique_scope", unique: true, length: { parent_type: 191, name: 191, scope_type: 191 }
  end

  create_table "environments", id: :integer do |t|
    t.string "name", null: false
    t.boolean "production", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "permalink", null: false
    t.index ["permalink"], name: "index_environments_on_permalink", unique: true
  end

  create_table "flowdock_flows", id: :integer do |t|
    t.string "name", null: false
    t.string "token", null: false
    t.integer "stage_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "jenkins_jobs", id: :integer do |t|
    t.integer "jenkins_job_id"
    t.string "name", null: false
    t.string "status"
    t.string "error"
    t.integer "deploy_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["deploy_id"], name: "index_jenkins_jobs_on_deploy_id"
    t.index ["jenkins_job_id"], name: "index_jenkins_jobs_on_jenkins_job_id"
  end

  create_table "jobs", id: :integer do |t|
    t.text "command", null: false
    t.integer "user_id", null: false
    t.integer "project_id", null: false
    t.string "status", default: "pending"
    t.text "output", limit: 268435455
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "commit"
    t.string "tag"
    t.integer "canceller_id"
    t.index ["project_id"], name: "index_jobs_on_project_id"
    t.index ["status"], name: "index_jobs_on_status"
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "kubernetes_cluster_deploy_groups", id: :integer do |t|
    t.integer "kubernetes_cluster_id", null: false
    t.integer "deploy_group_id", null: false
    t.string "namespace", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deploy_group_id"], name: "index_kubernetes_cluster_deploy_groups_on_deploy_group_id"
    t.index ["kubernetes_cluster_id"], name: "index_kuber_cluster_deploy_groups_on_kuber_cluster_id"
  end

  create_table "kubernetes_clusters", id: :integer do |t|
    t.string "name"
    t.string "description"
    t.string "config_filepath"
    t.string "config_context"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "ip_prefix"
    t.string "auth_method", default: "context", null: false
    t.string "api_endpoint"
    t.text "encrypted_client_cert"
    t.string "encrypted_client_cert_iv"
    t.text "encrypted_client_key"
    t.string "encrypted_client_key_iv"
    t.string "encryption_key_sha"
    t.boolean "verify_ssl", default: false, null: false
  end

  create_table "kubernetes_deploy_group_roles", id: :integer do |t|
    t.integer "project_id", null: false
    t.integer "deploy_group_id", null: false
    t.integer "replicas", null: false
    t.integer "limits_memory", null: false
    t.decimal "limits_cpu", precision: 6, scale: 2, null: false
    t.integer "kubernetes_role_id", null: false
    t.decimal "requests_cpu", precision: 6, scale: 2, null: false
    t.integer "requests_memory", null: false
    t.boolean "delete_resource", default: false, null: false
    t.boolean "no_cpu_limit", default: false, null: false
    t.index ["deploy_group_id"], name: "index_kubernetes_deploy_group_roles_on_deploy_group_id"
    t.index ["project_id", "deploy_group_id", "kubernetes_role_id"], name: "index_kubernetes_deploy_group_roles_on_project_dg_kr", unique: true
  end

  create_table "kubernetes_namespaces" do |t|
    t.string "name", null: false
    t.string "comment", limit: 512
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_kubernetes_namespaces_on_name", unique: true, length: 191
  end

  create_table "kubernetes_release_docs", id: :integer do |t|
    t.integer "kubernetes_role_id", null: false
    t.integer "kubernetes_release_id", null: false
    t.integer "replica_target", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "deploy_group_id"
    t.decimal "limits_cpu", precision: 6, scale: 2, null: false
    t.integer "limits_memory", null: false
    t.text "resource_template", limit: 1073741823
    t.decimal "requests_cpu", precision: 6, scale: 2, null: false
    t.integer "requests_memory", null: false
    t.boolean "delete_resource", default: false, null: false
    t.boolean "no_cpu_limit", default: false, null: false
    t.index ["kubernetes_release_id"], name: "index_kubernetes_release_docs_on_kubernetes_release_id"
    t.index ["kubernetes_role_id"], name: "index_kubernetes_release_docs_on_kubernetes_role_id"
  end

  create_table "kubernetes_releases", id: :integer do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.integer "project_id", null: false
    t.integer "deploy_id"
    t.string "git_sha", limit: 40, null: false
    t.string "git_ref"
    t.string "blue_green_color"
  end

  create_table "kubernetes_roles", id: :integer do |t|
    t.integer "project_id", null: false
    t.string "name", null: false
    t.string "config_file"
    t.string "service_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "resource_name", null: false
    t.boolean "autoscaled", default: false, null: false
    t.boolean "blue_green", default: false, null: false
    t.index ["project_id"], name: "index_kubernetes_roles_on_project_id"
    t.index ["resource_name", "deleted_at"], name: "index_kubernetes_roles_on_resource_name_and_deleted_at", unique: true, length: { resource_name: 191 }
    t.index ["service_name", "deleted_at"], name: "index_kubernetes_roles_on_service_name_and_deleted_at", unique: true, length: { service_name: 191 }
  end

  create_table "kubernetes_stage_roles" do |t|
    t.integer "stage_id", null: false
    t.integer "kubernetes_role_id", null: false
    t.boolean "ignored", default: false, null: false
  end

  create_table "kubernetes_usage_limits" do |t|
    t.integer "project_id"
    t.integer "scope_id"
    t.string "scope_type"
    t.integer "memory", null: false
    t.decimal "cpu", precision: 6, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "comment", limit: 512
    t.index ["project_id"], name: "index_kubernetes_usage_limits_on_project_id"
    t.index ["scope_type", "scope_id", "project_id"], name: "index_kubernetes_usage_limits_on_scope", unique: true, length: { scope_type: 20 }
  end

  create_table "locks", id: :integer do |t|
    t.integer "resource_id"
    t.integer "user_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string "description", limit: 1024
    t.boolean "warning", default: false, null: false
    t.datetime "delete_at"
    t.string "resource_type"
    t.index ["resource_id", "resource_type", "deleted_at"], name: "index_locks_on_resource_id_and_resource_type_and_deleted_at", unique: true, length: { resource_type: 40 }
  end

  create_table "new_relic_applications", id: :integer do |t|
    t.string "name"
    t.integer "stage_id"
    t.index ["stage_id", "name"], name: "index_new_relic_applications_on_stage_id_and_name", unique: true
  end

  create_table "oauth_access_grants", id: :integer do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["application_id"], name: "fk_rails_b4b53e07b8"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true, length: 191
  end

  create_table "oauth_access_tokens", id: :integer do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.string "description"
    t.datetime "last_used_at"
    t.index ["application_id"], name: "fk_rails_732cb83ab7"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true, length: 191
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true, length: 191
  end

  create_table "oauth_applications", id: :integer do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "confidential", default: true, null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true, length: 191
  end

  create_table "outbound_webhooks", id: :integer do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.integer "project_id", null: false
    t.integer "stage_id", null: false
    t.string "url", null: false
    t.string "username"
    t.string "password"
    t.index ["deleted_at"], name: "index_outbound_webhooks_on_deleted_at"
    t.index ["project_id"], name: "index_outbound_webhooks_on_project_id"
  end

  create_table "project_environment_variable_groups", id: :integer do |t|
    t.integer "project_id", null: false
    t.integer "environment_variable_group_id", null: false
    t.index ["environment_variable_group_id"], name: "project_environment_variable_groups_group_id"
    t.index ["project_id", "environment_variable_group_id"], name: "project_environment_variable_groups_unique_group_id", unique: true
  end

  create_table "projects", id: :integer do |t|
    t.string "name", null: false
    t.string "repository_url", null: false
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "token"
    t.string "release_branch"
    t.string "permalink", null: false
    t.text "description"
    t.string "owner"
    t.boolean "include_new_deploy_groups", default: false, null: false
    t.string "docker_release_branch"
    t.string "release_source", default: "any", null: false
    t.integer "build_command_id"
    t.text "dashboard"
    t.boolean "docker_image_building_disabled", default: false, null: false
    t.string "dockerfiles"
    t.boolean "build_with_gcb", default: false, null: false
    t.boolean "show_gcr_vulnerabilities", default: false, null: false
    t.boolean "kubernetes_allow_writing_to_root_filesystem", default: false, null: false
    t.boolean "jenkins_status_checker", default: false, null: false
    t.boolean "use_env_repo", default: false, null: false
    t.integer "kubernetes_rollout_timeout"
    t.integer "kubernetes_namespace_id"
    t.boolean "config_service", default: false, null: false
    t.index ["build_command_id"], name: "index_projects_on_build_command_id"
    t.index ["kubernetes_namespace_id"], name: "index_projects_on_kubernetes_namespace_id"
    t.index ["permalink"], name: "index_projects_on_permalink", unique: true, length: 191
    t.index ["token"], name: "index_projects_on_token", unique: true, length: 191
  end

  create_table "releases", id: :integer do |t|
    t.integer "project_id", null: false
    t.string "commit", null: false
    t.string "number", limit: 20, default: "1", null: false
    t.integer "author_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["project_id", "number"], name: "index_releases_on_project_id_and_number", unique: true
  end

  create_table "rollbar_dashboards_settings" do |t|
    t.string "base_url", null: false
    t.string "read_token", null: false
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "account_and_project_name"
    t.index ["project_id"], name: "index_rollbar_dashboards_settings_on_project_id"
  end

  create_table "rollbar_webhooks" do |t|
    t.text "webhook_url", null: false
    t.string "access_token", null: false
    t.string "environment", null: false
    t.integer "stage_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stage_id"], name: "index_rollbar_webhooks_on_stage_id"
  end

  create_table "secret_sharing_grants" do |t|
    t.string "key", null: false
    t.integer "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_secret_sharing_grants_on_key", length: 191
    t.index ["project_id", "key"], name: "index_secret_sharing_grants_on_project_id_and_key", unique: true, length: { key: 160 }
  end

  create_table "secrets", id: false do |t|
    t.string "id"
    t.string "encrypted_value", null: false
    t.string "encrypted_value_iv", null: false
    t.string "encryption_key_sha", null: false
    t.integer "updater_id", null: false
    t.integer "creator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: false, null: false
    t.string "comment"
    t.timestamp "deprecated_at"
    t.index ["id"], name: "index_secrets_on_id", unique: true, length: 191
  end

  create_table "slack_channels", id: :integer do |t|
    t.string "name", null: false
    t.string "channel_id", null: false
    t.integer "stage_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["stage_id"], name: "index_slack_channels_on_stage_id"
  end

  create_table "slack_identifiers", id: :integer do |t|
    t.integer "user_id"
    t.text "identifier", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_slack_identifiers_on_identifier", length: 12
    t.index ["user_id"], name: "index_slack_identifiers_on_user_id", unique: true
  end

  create_table "slack_webhooks", id: :integer do |t|
    t.text "webhook_url", null: false
    t.string "channel"
    t.integer "stage_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "before_deploy", default: false, null: false
    t.boolean "buddy_box", default: false, null: false
    t.boolean "on_deploy_failure", default: false, null: false
    t.boolean "buddy_request", default: false, null: false
    t.boolean "on_deploy_success", default: false, null: false
    t.index ["stage_id"], name: "index_slack_webhooks_on_stage_id"
  end

  create_table "stage_commands", id: :integer do |t|
    t.integer "stage_id"
    t.integer "command_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.index ["command_id"], name: "index_stage_commands_on_command_id"
    t.index ["stage_id"], name: "index_stage_commands_on_stage_id"
  end

  create_table "stages", id: :integer do |t|
    t.string "name", null: false
    t.integer "project_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "order", null: false
    t.datetime "deleted_at"
    t.boolean "confirm", default: true, null: false
    t.string "datadog_tags"
    t.boolean "update_github_pull_requests", default: false, null: false
    t.boolean "deploy_on_release", default: false, null: false
    t.boolean "comment_on_zendesk_tickets", default: false, null: false
    t.boolean "production", default: false, null: false
    t.string "permalink", null: false
    t.boolean "use_github_deployment_api", default: false, null: false
    t.text "dashboard"
    t.boolean "email_committers_on_automated_deploy_failure", default: false, null: false
    t.string "static_emails_on_automated_deploy_failure"
    t.string "datadog_monitor_ids"
    t.string "jenkins_job_names"
    t.string "next_stage_ids"
    t.boolean "no_code_deployed", default: false, null: false
    t.boolean "is_template", default: false, null: false
    t.boolean "notify_airbrake", default: false, null: false
    t.integer "template_stage_id"
    t.boolean "jenkins_email_committers", default: false, null: false
    t.boolean "kubernetes", default: false, null: false
    t.boolean "run_in_parallel", default: false, null: false
    t.boolean "jenkins_build_params", default: false, null: false
    t.boolean "cancel_queued_deploys", default: false, null: false
    t.boolean "no_reference_selection", default: false, null: false
    t.boolean "periodical_deploy", default: false, null: false
    t.boolean "builds_in_environment", default: false, null: false
    t.boolean "block_on_gcr_vulnerabilities", default: false, null: false
    t.boolean "notify_assertible", default: false, null: false
    t.string "notify_email_address"
    t.float "average_deploy_time"
    t.string "prerequisite_stage_ids"
    t.string "default_reference"
    t.boolean "full_checkout", default: false, null: false
    t.string "aws_sts_iam_role_arn"
    t.integer "aws_sts_iam_role_session_duration"
    t.boolean "allow_redeploy_previous_when_failed", default: false, null: false
    t.string "github_pull_request_comment"
    t.index ["project_id", "permalink"], name: "index_stages_on_project_id_and_permalink", unique: true, length: { permalink: 191 }
    t.index ["template_stage_id"], name: "index_stages_on_template_stage_id"
  end

  create_table "stars", id: :integer do |t|
    t.integer "user_id", null: false
    t.integer "project_id", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id", "project_id"], name: "index_stars_on_user_id_and_project_id", unique: true
  end

  create_table "user_project_roles", id: :integer do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.integer "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_user_project_roles_on_project_id"
    t.index ["user_id", "project_id"], name: "index_user_project_roles_on_user_id_and_project_id", unique: true
  end

  create_table "users", id: :integer do |t|
    t.string "name", null: false
    t.string "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "role_id", default: 0, null: false
    t.datetime "deleted_at"
    t.string "external_id"
    t.boolean "desktop_notify", default: false, null: false
    t.boolean "integration", default: false, null: false
    t.boolean "access_request_pending", default: false, null: false
    t.string "time_format", default: "relative", null: false
    t.datetime "last_login_at"
    t.datetime "last_seen_at"
    t.index ["external_id", "deleted_at"], name: "index_users_on_external_id_and_deleted_at", unique: true
  end

  create_table "vault_servers", id: :integer do |t|
    t.string "name", null: false
    t.string "address", null: false
    t.string "encrypted_token", null: false
    t.string "encrypted_token_iv", null: false
    t.string "encryption_key_sha", null: false
    t.boolean "tls_verify", default: false, null: false
    t.text "ca_cert"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "versioned_kv", default: false, null: false
    t.boolean "preferred_reader", default: false, null: false
    t.index ["name"], name: "index_vault_servers_on_name", unique: true, length: 191
  end

  create_table "versions", id: :integer do |t|
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object", limit: 1073741823
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", length: { item_type: 191 }
  end

  create_table "webhooks", id: :integer do |t|
    t.integer "project_id", null: false
    t.integer "stage_id", null: false
    t.string "branch", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deleted_at"
    t.string "source", null: false
    t.index ["project_id", "branch"], name: "index_webhooks_on_project_id_and_branch"
    t.index ["stage_id", "branch"], name: "index_webhooks_on_stage_id_and_branch"
  end

  add_foreign_key "deploy_groups", "environments"
  add_foreign_key "deploys", "deploys", column: "triggering_deploy_id"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
end
