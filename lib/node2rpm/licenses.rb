module Node2RPM
  class Licenses
    def initialize(json)
      @json = json
      @license ||= ''
    end

    def parse(json = @json, license = @license)
      json.each do |k, v|
        if v[:license].nil?
          puts "Warning: #{k} has no license" \
               ', please confirm by visiting' \
               " https://www.npmjs.org/package/#{k}" \
               ' and add it later to the specfile.'
        else
          if v[:license] == 'BSD'
            puts "Warning: #{k}'s license is BSD" \
                 ', please verify the clauses by visiting' \
                 " https://www.npmjs.org/package/#{k}."
          end

          lic = inspect(v[:license])
          if license.empty?
            license << lic
          else
            license.index(lic) || license << "\sAND\s" + lic
          end
          v[:dependencies].empty? || parse(v[:dependencies], license)
        end
      end

      license
    end

    private

    def inspect(license)
      license.instance_of?(Hash) ? license['type'] : license
    end
  end
end
