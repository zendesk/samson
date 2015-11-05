samson.factory('kubernetesReleaseGroupFactory', function(buildFactory) {

  function KubernetesReleaseGroup(id, created_at, created_by, build, deploy_groups) {
    this.id = id;
    this.created_at = created_at;
    this.created_by = created_by;
    this.build = build;
    this.deploy_groups = deploy_groups;
  }

  KubernetesReleaseGroup.build = function(data) {
    var build = buildFactory.build(data.build);

    var deploy_groups = data.deploy_groups.map(function(deploy_group){
      return deploy_group.name;
    });

    return new KubernetesReleaseGroup(
      data.id,
      data.created_at,
      data.user.name,
      build,
      deploy_groups
    );
  };

  return KubernetesReleaseGroup;
});
