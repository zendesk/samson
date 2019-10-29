# frozen_string_literal: true

StagesController.class_eval do
  prepend(
    Module.new do
      def resource_params
        stage_params = super
        stage_params[:stage_external_setup_hook_attributes]['_destroy'] = '1' if setup_hook_empty?(stage_params)
        stage_params
      end

      private

      def setup_hook_empty?(p)
        p[:stage_external_setup_hook_attributes] &&
          p[:stage_external_setup_hook_attributes][:external_setup_hook_id].blank?
      end
    end
  )
end
