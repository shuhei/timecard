# Timecard

Generate event summaries from OS X Calendar app.

## Installation

```
$ git clone $THIS_REPO
$ bundle install
```

## Usage

```
$ ruby lib/cal.rb "Name of Calendar" 2013 9
$ ruby lib/cal.rb "Name of Calendar" 2013 9 4
```

## Test

```
$ rspec
```

## TODO

- Support daily recurrence
- Support monthly recurrence
- Support yearly recurrence
- Generate hours matrix for multiple calendars
- Load calendar config
- Handle multiple-days events
