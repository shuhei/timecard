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
    end_cond = Appscript.its.end_date.lt((date + 1).beginning_of_day)
    start_cond.and(end_cond)
  end

  def not_in_day(date)
    start_cond = Appscript.its.start_date.lt(date.beginning_of_day)
    end_cond = Appscript.its.end_date.ge((date + 1).beginning_of_day)
    start_cond.or(end_cond)
  end

  def recurrent
    Appscript.its.recurrence.contains('INTERVAL')
  end

  def title
    @obj.title.get
  end
end

class Event
  DAYS_IN_THE_WEEK = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']

  attr_reader :rec

  def initialize(obj)
    @obj = obj

    rec_str = @obj.recurrence.get
    @rec = parse_recurrence(rec_str) unless rec_str == :missing_value

    raise "Overnight event is not supported: #{summary}" if overnight?

    if @rec
      raise "Only WKST MO is supported but #{@rec['WKST']} was given: #{summary}" if @rec['WKST'] && @rec['WKST'] != 'MO'
      raise "Only FREQ WEEKLY is supported but #{@rec['FREQ']} was given: #{summary}" unless ['DAILY', 'WEEKLY'].include?(@rec['FREQ'])
    end
  end

  def overnight?
    !(start_date.to_date == end_date.to_date || end_date == (start_date + 1.day).beginning_of_day)
  end

  def check_recurrent(date)
    range = recurrent_range_in_date(date)
    if range
      date.beginning_of_day <= range.min && range.max <= (date + 1).beginning_of_day
    else
      false
    end
  end

  def in_range?(date)
    is_started = start_date.to_date <= date
    if @rec['UNTIL']
      is_started && date <= @rec['UNTIL']
    else
      is_started
    end
  end

  # Check interval of weekly event.
  def happen_in_week?(date)
    if @rec['INTERVAL'] > 1
      # TODO: Use WKST. beginning_of_week= would be useful.
      week_diff = (date.beginning_of_week - start_date.beginning_of_week.to_date) / 7
      week_diff % @rec['INTERVAL'] == 0
    else
      true
    end
  end

  # Check day of the week.
  def happen_in_day_of_the_week?(date)
    byday = @rec['BYDAY']
    if byday
      byday.include?(DAYS_IN_THE_WEEK[date.wday])
    else
      date.wday == start_date.wday
    end
  end

  # Check interval of daily event.
  def happen_in_day?(date)
    if @rec['INTERVAL'] > 1
      date_diff = (date - start_date.to_date)
      date_diff % @rec['INTERVAL'] == 0
    else
      true
    end
  end

  # Returns time range on the date if the recurrent event happens on the date.
  # Returns nil otherwise.
  def recurrent_range_in_date(date)
    raise 'Not recurrent event' unless recurrent?

    # Check if it matches the date
    return nil unless in_range?(date)

    case @rec['FREQ']
    when 'WEEKLY' then
      return nil unless happen_in_week?(date)
      return nil unless happen_in_day_of_the_week?(date)
    when 'DAILY' then
      return nil unless happen_in_day?(date)
    else
      raise "Not supported FREQ: #{@rec['FREQ']}"
    end

    # Check if it matches the time in the day
    adjusted_start_date = date.beginning_of_day + (start_date - start_date.beginning_of_day)
    adjusted_end_date = adjusted_start_date + (end_date - start_date)
    (adjusted_start_date..adjusted_end_date)
  end

  def parse_recurrence(str)
    kvs = str.split(';').map do |compo|
      k, v = compo.split('=')
      v = v.to_i if k == 'INTERVAL'
      v = v.split(',') if k == 'BYDAY'
      v = Time.parse(v).getlocal.to_date if k == 'UNTIL'
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

  def csv_month(month)
    daily_sums = (month..(month.end_of_month)).map do |date|
      events = @cal.events_in_date(date)
      sum = events.inject(0) { |sum, event| sum + event.duration_in_hours }
      sum == 0 ? '' : sum
    end
    print "#{@cal.title},"
    puts daily_sums.join(',')
  end
end
