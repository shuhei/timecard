require 'appscript'
require_relative 'event'

class Calendar
  def initialize(obj)
    @obj = obj
    fetch_events
  end

  def fetch_events
    @events = @obj.events.get.map do |event_obj|
      Event.new(event_obj)
    end
  end

  def events_in_date(date)
    events = one_time_events_in_date(date) + recurrent_events_in_date(date)
    events.sort_by(&:start_time)
  end

  def one_time_events_in_date(date)
    @events.select do |event|
      date.beginning_of_day <= event.start_date &&
        event.end_date < (date + 1).beginning_of_day
    end
  end

  def recurrent_events_in_date(date)
    @events.select do |event|
      event.recurrent?  &&
        (event.start_date < date.beginning_of_day || (date + 1).beginning_of_day <= event.end_date) &&
        event.check_recurrent(date)
    end
  end

  def title
    @obj.title.get
  end
end
