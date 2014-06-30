require 'active_support/time'

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

    sum = events.reduce(0) { |sum, event| sum + event.duration_in_hours }
    puts "#{date}: #{sum} hours"
    events.each do |event|
      puts "  #{event.start_time} - #{event.end_time}: #{event.summary}"
    end
  end

  def days_in_month(month)
    (month..(month.end_of_month)).map do |date|
      events = @cal.events_in_date(date)
      events.reduce(0) { |sum, event| sum + event.duration_in_hours }
    end
  end
end
