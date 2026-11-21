module Assistant
  # One Ollama call at a time. This server has 2 GB of RAM, so a second model
  # load would be killed. Other questions wait and run when the lock is free.
  class Lane
    LOCK_KEY = 842_184_21

    def self.exclusive
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        locked = connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")
        return false unless locked == true || locked == "t"

        begin
          yield
        ensure
          connection.select_value("SELECT pg_advisory_unlock(#{LOCK_KEY})")
        end
      end
    end
  end
end
