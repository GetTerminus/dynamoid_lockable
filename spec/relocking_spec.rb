# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DynamoidLockable do
  let(:klass) do
    Class.new do
      include Dynamoid::Document
      include DynamoidLockable

      table name: :test, key: :custom_id

      locks_with :no_relock, lock_for: 2, relock_every: nil
      locks_with :with_relock, lock_for: 3
    end
  end
  let(:instance) { klass.create }

  describe 'relocking' do
    it 'holds the lock' do
      instance.perform_with_lock(:with_relock) do
        expect do
          sleep 3
        end.to change { instance.reload.with_relock_locked_until }
      end
    end

    it "doesn't renew the lock when not requested" do
      instance.perform_with_lock(:no_relock) do
        expect do
          sleep 3
        end.not_to change { instance.reload.with_relock_locked_until }
      end
    end

    it "doesn't recreate removed locked items" do
      expect do
        instance.perform_with_lock(:with_relock) do
          instance.destroy!
        end
      rescue DynamoidLockable::CouldNotUnlock
      end.to change {
        instance.class.where(custom_id: instance.custom_id).count
      }.from(1).to(0)
    end

    it "raises an error when it can't unlock" do
      expect do
        instance.perform_with_lock(:with_relock) do
          instance.destroy!
        end
      end.to raise_error(DynamoidLockable::CouldNotUnlock)
    end
  end

  describe 'lock reentry' do
    it 'allows lock reentry from the same thread' do
      expect do
        instance.lock(:no_relock)
        instance.lock(:no_relock)
      end.not_to raise_error
    end

    it 'errors if another thread tries to aquire the lock' do
      expect do
        t = Thread.new { instance.lock(:no_relock) }
        instance.lock(:no_relock)
        t.join
      end.to raise_error(DynamoidLockable::CouldNotAcquireLock)
    end
  end
end
