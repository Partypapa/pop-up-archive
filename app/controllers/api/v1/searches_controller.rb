class Api::V1::SearchesController < Api::V1::BaseController
  def show
    query_builder = QueryBuilder.new(params, current_user)
    page = params[:page].to_i

    @search = ItemResultsPresenter.new(Tire.search(index_name) do

      if page.present? && page > 1
        from (page - 1) * RESULTS_PER_PAGE
      end
      size RESULTS_PER_PAGE

      query_builder.query do |q|
        query &q
      end

      query_builder.facets do |my_facet|
        facet my_facet.name, &my_facet
      end

      query_builder.filters do |my_filter|
        filter my_filter.type, my_filter.value
      end

      highlight transcript: { number_of_fragments: 0 }
    end.results)
      
    respond_with @search
  end

  def index
    @recent =  ItemResultsPresenter.new(Tire.search('items') do
      query_builder.query do
        string '*'
      end
      
      sort {by :updated_at, 'desc'}      
      size 6
      end.results)
    respond with @recent
  end
  
  private

  def index_name
    if current_user.present? && current_user.id == 1 && Tire.index('items_st').exists?
      @debug = true
      'items_st'
    else
      'items'
    end
  end
    
end
