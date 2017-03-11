module Node2RPM
  # Node2RPM only keeps internet files within a week.
  class Cache
    def initialize(file)
      @mtime = File.mtime(file)
    end

    def clear?
      now = Time.now
      one_week = 2 * 7 * 24 * 60 * 60
      now - @mtime > one_week ? true : false
    end
  end
end
