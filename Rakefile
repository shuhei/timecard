require 'rspec/core/rake_task'
require 'active_support/time'
require 'yaml'
require './lib/cal'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = ['-c']
end

task :default => :spec

namespace :report do
  def setup_reporter(calendar_name)
    ical = Appscript.app('iCal')
    cal = Calendar.new(ical.calendars[calendar_name])
    reporter = Reporter.new(cal)
  end

  def load_config
    config_path = File.join(File.dirname(__FILE__), 'config.yml')
    YAML::load(File.read(config_path))
  end

  desc 'Output monthly report'
  task :monthly, :calendar_name, :month do |t, args|
    setup_reporter(args[:calendar_name]).report_month(Date.parse(args[:month]))
  end

  desc 'Output daily report'
  task :daily, :calendar_name, :date do |t, args|
    setup_reporter(args[:calendar_name]).report_date(Date.parse(args[:date]))
  end

  desc 'Output monthly matrix'
  task :matrix, :month do |t, args|
    month = Date.parse(args[:month])
    print "Calendar\t"
    puts (month..(month.end_of_month)).map { |date| date.strftime('%m-%d') }.join("\t")

    config = load_config
    config.map do |label, cals|
      rows = cals.map do |cal_name|
        reporter = setup_reporter(cal_name)
        reporter.days_in_month(month)
      end
      summary = rows.inject([0] * month.end_of_month.day) do |sum, row|
        sum.zip(row).map do |pair|
          pair[0] + pair[1]
        end
      end.map do |hours|
        hours == 0 ? '' : hours.to_s
      end

      print "\"#{label}\"\t"
      puts summary.join("\t")
    end
  end
end
