class Api::V1::SearchesController < ApplicationController
  include ::ParamsHelper

  before_action :set_search, only: [:show, :update, :destroy]

  rescue_from UnpermittedParamValue, with: :unpermitted_param_value_response
  rescue_from UnsupportedParamCombo, with: :unsupported_param_combo_response
  rescue_from ActiveRecord::RecordInvalid, with: :save_search_validation_error_response

  def create
    new_search = Search.create(search_create_params)
    new_search.save!
    render json: Api::V1::SearchSerializer.new(new_search), status: 201
  end

  def index
    render json: Api::V1::SearchSerializer.new(requested_searches).serializable_hash, status: 200
  end

  def show
    render json: Api::V1::SearchSerializer.new(@search), status: 200
  end

  def update
    @search.update(search_update_params)
    render json: Api::V1::SearchSerializer.new(@search), status: 200
  end

  def destroy
    @search.destroy
    render status: 204
  end

  private
  def filter_searches(topic)
    if topic.nil?
      Search.all
    else
      Search.topic_filtered(topic)
    end
  end

  def organize_searches(searches, order_request, sort_request)
    if sort_request.present? && order_request.present?
      raise UnsupportedParamCombo.new(params:[ :ordered_by, :sorted_by_topic])
    elsif sort_request.present?
      if sort_request.downcase != "true"
        raise UnpermittedParamValue.new(key: :sorted_by_topic, value: search_index_params[:sorted_by_topic])
      end
      searches.topic_sorted
    elsif order_request.present?
      validate_ordered_by_params
      searches.creation_ordered(order_request)
    else
      searches
    end
  end

  def requested_searches
    topic = search_index_params[:topic]
    order_request = search_index_params[:ordered_by]
    sort_request = search_index_params[:sorted_by_topic]

    filtered_searches = filter_searches(topic)

    organize_searches(filtered_searches, order_request, sort_request)
  end

  def save_search_validation_error_response
    render json: { error: "Mysterious validation error: it's possible this search url may already be saved." },
           status: 400
  end

  def search_create_params
    params.require(:search).permit(:topic, :url)
  end

  def search_index_params
    params.permit(:ordered_by, :sorted_by_topic, :topic)
  end

  def search_update_params
    # Users may only update allowed fields
    params.require(:search).permit(:topic)
  end

  def set_search
    @search = Search.find_by_id(params[:id])
    if @search.nil?
      raise ActiveRecord::RecordNotFound
    end
  end

  def validate_ordered_by_params
    if !['newist_created', 'oldest_created'].include? search_index_params[:ordered_by]
      raise UnpermittedParamValue.new(key: :ordered_by, value: search_index_params[:ordered_by])
    end
  end
end
