require 'appscript'
require 'active_support/all'

class Calendar
  def initialize(obj)
    @obj = obj
  end

  def events_in_date(date)
    one_time_events_in_date(date) + recurrent_events_in_date(date)
  end

  def one_time_events_in_date(date)
    @obj.events[in_day(date)].get.map do |event_obj|
      Event.new(event_obj)
    end
  end

  def recurrent_events_in_date(date)
    events = @obj.events[not_in_day(date).and(recurrent)]
    events.get.map do |event_obj|
      Event.new(event_obj)
    end.select do |event|
      event.check_recurrent(date)
    end
  end

  def in_day(date)
    start_cond = Appscript.its.start_date.ge(date.beginning_of_day)
    end_cond = Appscript.its.end_date.lt(date.end_of_day)
    start_cond.and(end_cond)
  end

  def not_in_day(date)
    start_cond = Appscript.its.start_date.lt(date.beginning_of_day)
    end_cond = Appscript.its.end_date.ge(date.end_of_day)
    start_cond.or(end_cond)
  end

  def recurrent
    Appscript.its.recurrence.contains('INTERVAL')
  end
end

class Event
  DAYS_IN_THE_WEEK = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']

  def initialize(obj)
    @obj = obj

    rec_str = @obj.recurrence.get
    @rec = parse_recurrence(rec_str) unless rec_str == :missing_value

    if @rec
      raise "Only WKST MO is supported but #{@rec['WKST']} was given" if @rec['WKST'] && @rec['WKST'] != 'MO'
      raise "Only FREQ WEEKLY is supported but #{@rec['FREQ']} was given" if @rec['FREQ'] != 'WEEKLY'
    end
  end

  def check_recurrent(date)
    range = recurrent_range_in_date(date)
    if range
      date.beginning_of_day <= range.min && range.max < date.end_of_day
    else
      false
    end
  end

  def in_recurrence?(date)
    start_date <= date
  end

  def happen_in_week?(date)
    if @rec['INTERVAL'] > 1
      # TODO: Use WKST. beginning_of_week= would be useful.
      week_diff = (date.beginning_of_week - start_date.beginning_of_week.to_date) / 7
      week_diff % @rec['INTERVAL'] == 0
    else
      true
    end
  end

  def happen_in_day_of_the_week?(date)
    byday = @rec['BYDAY']
    if byday
      byday.include?(DAYS_IN_THE_WEEK[date.wday])
    else
      date.wday == start_date.wday
    end
  end

  # Returns time range on the date if the recurrent event happens on the date.
  # Returns nil otherwise.
  def recurrent_range_in_date(date)
    raise 'Not recurrent event' unless recurrent?
    return nil unless in_recurrence?(date)
    return nil unless happen_in_week?(date)
    return nil unless happen_in_day_of_the_week?(date)

    adjusted_start_date = date.beginning_of_day + (start_date - start_date.beginning_of_day)
    adjusted_end_date = adjusted_start_date + (end_date - start_date)
    (adjusted_start_date..adjusted_end_date)
  end

  def parse_recurrence(str)
    kvs = str.split(';').map do |compo|
      k, v = compo.split('=')
      v = v.to_i if k == 'INTERVAL'
      v = v.split(',') if k == 'BYDAY'
      [k, v]
    end
    Hash[*(kvs.flatten(1))]
  end

  def recurrent?
    @rec != nil
  end

  def method_missing(method_name, *args, &block)
    if @obj.respond_to?(method_name)
      @obj.send(method_name).get
    else
      super
    end
  end
end

if __FILE__ == $0
  calendar_name = ARGV[0]
  date_args = ARGV[1..3].map(&:to_i)

  ical = Appscript.app('iCal')
  cal = Calendar.new(ical.calendars[calendar_name])
  date = Date.new(*date_args)
  puts cal.events_in_date(date).map(&:summary)
end
