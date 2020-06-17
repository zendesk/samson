# frozen_string_literal: true
DeployGroupsController.class_eval do
  prepend(
    Module.new do
      def deploy_group_params
        dg_params = super
        dg_params[:cluster_deploy_group_attributes]['_destroy'] = '1' if kubernetes_cluster_empty?(dg_params)
        dg_params
      end

      private

      def kubernetes_cluster_empty?(dg_params)
        dg_params[:cluster_deploy_group_attributes] &&
          dg_params[:cluster_deploy_group_attributes][:kubernetes_cluster_id].blank?
      end
    end
  )
end
