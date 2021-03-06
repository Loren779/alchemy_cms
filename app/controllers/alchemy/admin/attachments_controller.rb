# frozen_string_literal: true

module Alchemy
  module Admin
    class AttachmentsController < ResourcesController
      include UploaderResponses

      helper 'alchemy/admin/tags'

      def index
        @query = Attachment.ransack(params[:q])
        @attachments = @query.result

        if params[:tagged_with].present?
          @attachments = @attachments.tagged_with(params[:tagged_with])
        end

        if params[:file_type].present?
          @attachments = @attachments.with_file_type(params[:file_type])
        end

        @attachments = @attachments
          .page(params[:page] || 1)
          .per(15)

        if in_overlay?
          archive_overlay
        end
      end

      # The resources controller renders the edit form as default for show actions.
      def show
        render :show
      end

      def create
        @attachment = Attachment.create(attachment_attributes)
        handle_uploader_response(status: :created)
      end

      def update
        @attachment.update(attachment_attributes)
        if attachment_attributes['file'].present?
          handle_uploader_response(status: :accepted)
        else
          render_errors_or_redirect(
            @attachment,
            admin_attachments_path(search_filter_params),
            Alchemy.t("File successfully updated")
          )
        end
      end

      def destroy
        name = @attachment.name
        @attachment.destroy
        @url = admin_attachments_url(search_filter_params)
        flash[:notice] = Alchemy.t('File deleted successfully', name: name)
      end

      def download
        @attachment = Attachment.find(params[:id])
        send_file @attachment.file.path, {
          filename: @attachment.file_name,
          type: @attachment.file_mime_type
        }
      end

      private

      def search_filter_params
        params.except(*COMMON_SEARCH_FILTER_EXCLUDES + [:attachment]).permit(
          *common_search_filter_includes + [
            :file_type,
            :content_id
          ]
        )
      end

      def handle_uploader_response(status:)
        if @attachment.valid?
          render successful_uploader_response(file: @attachment, status: status)
        else
          render failed_uploader_response(file: @attachment)
        end
      end

      def in_overlay?
        params[:content_id].present?
      end

      def archive_overlay
        @content = Content.find_by(id: params[:content_id])
        respond_to do |format|
          format.html { render partial: 'archive_overlay' }
          format.js   { render action:  'archive_overlay' }
        end
      end

      def attachment_attributes
        params.require(:attachment).permit(:file, :name, :file_name, :tag_list)
      end
    end
  end
end
