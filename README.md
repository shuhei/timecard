# Timecard

Generate event summaries from OS X Calendar app.

## Installation

```
$ git clone $THIS_REPO
$ cd timecard
$ bundle install
```

## Usage

```
$ bin/rake report:monthly["Name of Calendar",2013/9]
$ bin/rake report:daily["Name of Calendar",2013/9/4]
$ bin/rake report:matrix[2013/9]
```

## Test

```
$ rspec
```

## TODO

- Support monthly recurrence
- Support yearly recurrence
- Handle overnight events
