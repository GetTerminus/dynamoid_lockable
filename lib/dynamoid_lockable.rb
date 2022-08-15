# frozen_string_literal: true

require 'dynamoid_lockable/version'
require 'dynamoid_advanced_where'

require 'securerandom'

module DynamoidLockable
  class Error < StandardError; end

  class LockingError < Error; end
  class CouldNotAcquireLock < LockingError; end
  class CouldNotUnlock < LockingError; end

  DEFAULT_LOCK_TIME = 15 * 60

  def lock(name, locker_name: self.class.locking_name)
    ensure_lockable_field(name)

    locked_until = Time.now + self.class.lock_config(name)[:duration]

    result = self.class
                 .lockable(name, locker_name: locker_name)
                 .upsert(
                   hash_key,
                   range_value,
                   "#{name}_locked_until": locked_until,
                   "#{name}_locked_by": locker_name
                 )

    raise CouldNotAcquireLock unless result

    # Prevents having to call reload, which we've seen take 20seconds
    # but still populates the value in memory, in case the code block
    # calls save and persists this copy again
    send("#{name}_locked_until=", locked_until)
    send("#{name}_locked_by=", locker_name)

    true
  end

  def unlock(name)
    ensure_lockable_field(name)

    result = self.class.unlockable(name)
                 .upsert(hash_key, range_value, "#{name}_locked_until": nil)

    raise CouldNotUnlock unless result

    true
  end

  def create_relock_thread(name)
    locker_name = self.class.locking_name

    Thread.new do
      config = self.class.lock_config(name)
      loop do
        lock(name, locker_name: locker_name)

        sleep config[:relock_every]
      end
    end
  end

  def perform_with_lock(name)
    ensure_lockable_field(name)
    config = self.class.lock_config(name)

    result = lock(name)

    if config[:relock_every]&.positive?
      relock_thread = create_relock_thread(name)
    end

    yield
  ensure
    relock_thread&.exit
    unlock(name) if result # Don't try to unlock if you didn't acquire lock
  end

  def ensure_lockable_field(name)
    self.class.ensure_lockable_field(name)
  end

  module ClassMethods
    def locking_name
      Thread.current[:dynamo_lock_name] ||= SecureRandom.uuid
    end

    # TODO: Make this inheritance safe
    def lockable_fields
      @lockable_fields ||= {}
    end

    def lockable_fields=(val)
      @lockable_fields = val
    end

    def lock_config(name)
      lockable_fields[name.to_sym]
    end

    def locks_with(base_field, lock_for: DEFAULT_LOCK_TIME, relock_every: lock_for / 3)
      self.lockable_fields = lockable_fields.merge(
        base_field.to_sym => { duration: lock_for, relock_every: relock_every }
      )

      field  "#{base_field}_locked_until".to_sym, :datetime
      field  "#{base_field}_locked_by".to_sym, :string
    end

    def lockable(lock_name, locker_name: locking_name)
      ensure_lockable_field(lock_name)

      advanced_where do |r|
        key_filter(r) & (
          (r.send("#{lock_name}_locked_by") == locker_name) |
          !r.send("#{lock_name}_locked_until").exists? |
          (r.send("#{lock_name}_locked_until") < Time.now)
        )
      end
    end

    def ensure_lockable_field(name)
      raise "Lock #{name} unrecognized" unless lockable_fields.key?(name)
    end

    def unlockable(lock_name, locker_name: locking_name)
      ensure_lockable_field(lock_name)

      advanced_where do |r|
         key_filter(r) &
          (r.send("#{lock_name}_locked_by") == locker_name)
      end
    end

    def key_filter(condition_builder)
      if range_key
        condition_builder.public_send(self.hash_key).exists? & condition_builder.public_send(self.range_key).exists?
      else
        condition_builder.public_send(self.hash_key).exists?
      end
    end
  end

  def self.included(other)
    other.extend(ClassMethods)
  end
end
