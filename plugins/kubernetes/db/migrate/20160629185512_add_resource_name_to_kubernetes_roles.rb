# frozen_string_literal: true
class AddResourceNameToKubernetesRoles < ActiveRecord::Migration[4.2]
  def up
    add_column :kubernetes_roles, :resource_name, :string
    backfill_resource_names
    change_column_null :kubernetes_roles, :resource_name, false
    add_index :kubernetes_roles, [:resource_name, :deleted_at], unique: true, length: {resource_name: 191}
  end

  def down
    remove_index :kubernetes_roles, [:resource_name, :deleted_at]
    remove_column :kubernetes_roles, :resource_name
  end

  private

  # backfill all resource_name values from their last release
  def backfill_resource_names
    Kubernetes::Role.where(resource_name: nil).find_each do |role|
      warn "Role #{role.id} #{role.project.permalink}/#{role.name}"
      if role.resource_name = parse_resource_name_from_template(role)
        warn "Using name #{role.resource_name}"
      else
        role.resource_name = "#{role.project.permalink}-#{role.name.parameterize}".tr('_', '-')
        warn "Using generated name #{role.resource_name}"
      end

      role.save(validate: false)
    end
  end

  def parse_resource_name_from_template(role)
    unless doc = Kubernetes::ReleaseDoc.where(kubernetes_role_id: role.id).last
      warn "No release doc found"
      return
    end

    unless template = doc.send(:raw_template)
      warn "No file found in git"
      return
    end

    unless elements = Array.wrap(Kubernetes::Util.parse_file(template, role.config_file)).compact
      warn "No resource found in template"
      return
    end

    unless resource = elements.detect { |e| ['Deployment', 'DaemonSet', 'Job'].include?(e['kind']) }
      warn "No name found in resource"
      return
    end

    unless name = resource.fetch('metadata', {})['name']
      warn "no name found in resource"
      return
    end

    if Kubernetes::Role.where(resource_name: name).exists?
      warn "Role with name #{name} already exists"
      return
    end

    name
  end
end
