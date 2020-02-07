# DynamoidLockable
`DynamoidLockable` provides a interface for pessimistic locking for Dynamoid models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dynamoid_lockable'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install dynamoid_lockable

## Usage
```
class MyModel
  include Dynamoid::Document
  include DynamoidLockable

  # Models may have more than one lock discriminated by name.
  # Creates a lock named :importing, which locks by default for 5 minutes and will refresh the lock every 10 seconds.
  # Default values:
  #  lock_for: 10 minutes
  #  relock_every: 1/3 of lock_for
  locks_with :importing, lock_for: 5 * 60, relock_every: 10
end

thing = MyModel.find('abcd')

# Most basic usage
thing.perform_with_lock(:importing) do
  # do whatever you like in here, record will remain locked as long as this block is executing and the
  # thread is able to do work
end

# Manually locking and unlocking
thing.lock(:importing)
# WARNING! Lock is not persisted, you have 5 minutes to complete your task
do_work(thing)
thing.unlock(:importing)

# You can also search by entities which are lockable (unlocked, locks expired or eleigible for reentry)
search = MyModel.lockable(:importing).first

# Note that `lockable` returns a dynamoid_advanced_where chain, so additional where clauses may be appended

# Locks support reentry from the same thread
thing.lock(:importing)
thing.lock(:importing) # No error

Thread.new do
  thing.lock(:importing) # Error: Concerns::Lockable::CouldNotAcquireLock
end
```

A note on the options:
* *locks_for* - should be a reasonably high number, setting it too small will result in excessive DynamoDB usage
* *relock_every* - should be a positive number, nil or 0 will result in the relock process being disabled

## Errors
* If unable to obtain a lock, `DynamoidLockable::CouldNotAcquireLock` is raised
* If unable to obtain to release a lock, `DynamoidLockable::CouldNotUnlock` is raised

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/GetTerminus/dynamoid_lockable.

