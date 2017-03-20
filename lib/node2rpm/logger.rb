module Node2RPM
  class Logger
    def initialize(text)
      open(LOG, 'a+:UTF-8') { |f| f.write Time.now.to_s + "\s" + text + "\n" }
      puts text # debug
    end
  end
end
