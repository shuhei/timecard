require 'appscript'
require 'active_support/time'

class Calendar
  def initialize(obj)
    @obj = obj
  end

  def events_in_date(date)
    events = one_time_events_in_date(date) + recurrent_events_in_date(date)
    events.sort_by(&:start_time)
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

  attr_reader :rec

  def initialize(obj)
    @obj = obj

    rec_str = @obj.recurrence.get
    @rec = parse_recurrence(rec_str) unless rec_str == :missing_value

    if @rec
      raise "Only WKST MO is supported but #{@rec['WKST']} was given: #{summary}" if @rec['WKST'] && @rec['WKST'] != 'MO'
      raise "Only FREQ WEEKLY is supported but #{@rec['FREQ']} was given: #{summary}" if @rec['FREQ'] != 'WEEKLY'
      raise "UNTIL is not supported but #{@rec['UNTIL']} was given: #{summary}" if @rec['UNTIL']
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

  def in_range?(date)
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
    return nil unless in_range?(date)
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

  def duration_in_hours
    (end_date - start_date) / (60 * 60)
  end

  def start_time
    start_date.strftime('%H:%M')
  end

  def end_time
    end_date.strftime('%H:%M')
  end

  def method_missing(method_name, *args, &block)
    if @obj.respond_to?(method_name)
      @obj.send(method_name).get
    else
      super
    end
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
end

if __FILE__ == $0
  calendar_name = ARGV[0]

  ical = Appscript.app('iCal')
  cal = Calendar.new(ical.calendars[calendar_name])
  reporter = Reporter.new(cal)

  case ARGV.length
  when 3 then
    month_args = ARGV[1..2].map(&:to_i)
    reporter.report_month(Date.new(*month_args))
  when 4 then
    date_args = ARGV[1..3].map(&:to_i)
    reporter.report_date(Date.new(*date_args))
  else
    puts 'Specify Calendar name and month or date.'
    puts 'Example for month : ruby lib/cal.rb Hello 2013 9'
    puts 'Example for date  : ruby lib/cal.rb Hello 2013 9 4'
  end
end
