# Timecard

Generate event summaries from OS X Calendar app.

## Installation

```
$ git clone $THIS_REPO
$ bundle install
```

## Usage

```
$ rake report:monthly[Name of Calendar,2013/9]
$ rake report:daily[Name of Calendar,2013/9/4]
```

## Test

```
$ rspec
```

## TODO

- Support monthly recurrence
- Support yearly recurrence
- Generate hours matrix for multiple calendars
- Load calendar config
- Handle overnight events
