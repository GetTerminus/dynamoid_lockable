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

  let(:creation_function) { -> { klass.create(custom_id: SecureRandom.uuid) } }

  it_behaves_like 'a lockable dynamoid model'
end
