require 'appscript'
require_relative 'event'

# TODO: iCal responds too slowly. Try loading all events first and search on memory.
# event.properties_.get returns all the properties of the event.
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

class Reporter
  def initialize(cal)
    @cal = cal
  end

  def report_month(month)
    (month..(month.end_of_month)).each do |date|
      report_date(date)
    end
  end

  def report_date(date)
    events = @cal.events_in_date(date)

    puts "#{date}: #{events.inject(0) { |sum, event| sum + event.duration_in_hours }} hours"
    events.each do |event|
      puts "  #{event.start_time} - #{event.end_time}: #{event.summary}"
    end
  end

  def days_in_month(month)
    (month..(month.end_of_month)).map do |date|
      events = @cal.events_in_date(date)
      sum = events.inject(0) { |sum, event| sum + event.duration_in_hours }
    end
  end
end
