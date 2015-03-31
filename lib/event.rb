require 'active_support/time'

class Event
  DAYS_IN_THE_WEEK = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA']
  DAY_SYMBOLS = {
    'SU' => :sunday,
    'MO' => :monday,
    'TU' => :tuesday,
    'WE' => :wedenesday,
    'TH' => :thursday,
    'FR' => :friday,
    'SA' => :saturday
  }

  attr_reader :rec

  def initialize(obj)
    @props = obj.properties_.get

    rec_str = @props[:recurrence]
    @rec = parse_recurrence(rec_str) unless rec_str == :missing_value
    @excluded_dates = @props[:excluded_dates]

    @week_start = Date.beginning_of_week

    raise "Overnight recurrent event is not supported: #{@props.inspect}" if recurrent? && overnight?

    if @rec
      @week_start = DAY_SYMBOLS[@rec['WKST']] if DAY_SYMBOLS.has_key?(@rec['WKST'])
      unless ['DAILY', 'WEEKLY'].include?(@rec['FREQ'])
        message = "Only FREQ WEEKLY is supported but #{@rec['FREQ']} was given: #{@rec.inspect}"
        raise message
      end
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
      week_diff = (date.beginning_of_week(@week_start) - start_date.beginning_of_week(@week_start).to_date) / 7
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
    return nil if @excluded_dates && @excluded_dates.include?(adjusted_start_date)

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
    if @props.has_key?(method_name)
      @props[method_name]
    else
      super
    end
  end
end
