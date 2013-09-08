require 'rspec/core/rake_task'
require 'active_support/time'
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

  desc 'Output monthly report'
  task :monthly, :calendar_name, :month do |t, args|
    setup_reporter(args[:calendar_name]).report_month(Date.parse(args[:month]))
  end

  desc 'Output daily report'
  task :daily, :calendar_name, :date do |t, args|
    setup_reporter(args[:calendar_name]).report_date(Date.parse(args[:date]))
  end
end

