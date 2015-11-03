samson.factory('kubernetesRoleFactory', function() {

  function KubernetesRole(id, project_id, name, config_file, replicas, ram, cpu, service_name, deploy_strategy) {
    this.id = id;
    this.project_id = project_id;
    this.name = name;
    this.config_file = config_file;
    this.replicas = replicas;
    this.ram = ram;
    this.cpu = cpu;
    this.service_name = service_name;
    this.deploy_strategy = deploy_strategy;
  }

  KubernetesRole.build = function(data) {
    return new KubernetesRole(
      data.id,
      data.project_id,
      data.name,
      data.config_file,
      data.replicas,
      data.ram,
      data.cpu,
      data.service_name,
      data.deploy_strategy
    );
  };

  return KubernetesRole;
});
