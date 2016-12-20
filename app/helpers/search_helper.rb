module SearchHelper

  def set_tab value
    parameters = params.dup
    if parameters.include?('tab')
      parameters['tab'] = value
    else
      parameters.merge({'tab' => value})
    end
    return url_for(parameters)
  end

  def filter_link name, value, count, title = nil, html_options={}, &block
    parameters = params.dup
    title ||= (title || truncate(value.to_s, length: 30))

    #if there's already a filter of the same facet type, create/add to an array
    if parameters.include?(name)
      parameters[name] = Array.wrap(parameters[name]) | [value]
    else
      parameters[name] = value
    end

    parameters.delete('page') #remove the page option if it exists
    html_options.reverse_merge!(title: value.to_s)

    link_to parameters, html_options do
      if block_given?
        yield
      else
        title + content_tag(:span, "#{count}", class: 'facet-count')
      end
    end
  end

  def remove_filter_link name, value, html_options={}, title=nil, &block
    parameters = params.dup
    title ||= (title || truncate(value.to_s, length: 30))

    #delete a filter from an array or delete the whole facet if it is the only one
    if parameters.include?(name)
      if parameters[name].is_a?(Array)
        parameters[name].delete(value)
        # Go back to being just a singleton if only one element left
        parameters[name] = parameters[name].first if parameters[name].one?
      else
        parameters.delete(name)
      end
    end

    parameters.delete('page') #remove the page option if it exists
    html_options.reverse_merge!(title: value.to_s)

    link_to parameters, html_options do
      if block_given?
        yield
      else
      "#{title}&nbsp;<i class='glyphicon glyphicon-remove'></i>".html_safe
      end
    end
  end

  def show_more_link facet
    parameters = params.dup
    return link_to "<span style='font-weight: bold;'>Show more #{facet.humanize.pluralize.downcase}</span><i class='glyphicon glyphicon-chevron-down pull-right'></i>".html_safe, parameters.merge("#{facet}_all"=>true)
  end

  def show_less_link facet
    parameters = params.dup
    parameters.delete("#{facet}_all")
    return link_to "<span style='font-weight: bold;'>Show less #{facet.humanize.pluralize.downcase}</span><i class='glyphicon glyphicon-chevron-up pull-right'></i>".html_safe, parameters
  end

  def neatly_printed_date_range start, finish
    if start and finish
      if start.year != finish.year
        "#{day_month_year(start)} - #{day_month_year(finish)}"
      elsif start.month != finish.month
        "#{day_month(start)} - #{day_month(finish)} #{finish.year}"
      elsif start.day != finish.day
        "#{start.day} - #{finish.day} #{finish.strftime("%b")} #{finish.year}"
      else
        "#{day_month_year(start)}"
      end
    else
      return 'No date given'
    end

  end

  def neatly_printed_date date
    day_month_year date
  end

  private

  def day_month date
    return date.strftime("%d %b")
  end
  def day_month_year date
    return date.strftime("%d %b %Y")
  end


end
