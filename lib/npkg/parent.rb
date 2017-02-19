module NPKG
	class Parent
		def initialize(pkg,list)
			@pkg = pkg
			@json = NPKG::JSONObject.new(list).parse
		end

		def find(pkg=@pkg,parents=[])
			@json.each do |j|
				if j.name == pkg
					parents << j.parent
					find(j.parent,parents)
				end
			end
			return parents.reverse
		end

		def walk(str)
			parents = find

			if parents.size > 1
				for i in 1..(parents.size - 1) do
					str << "[\"#{parents[i]}\"][:dependencies]"
				end
			end

			str << "[\"#{@pkg}\"][:dependencies]"

			return str
		end
	end
end


list = {"gulp"=>{:version=>"3.9.1", :parent=>"_root", :dependencies=>{"archy"=>{:version=>"1.0.0", :parent=>"gulp", :dependencies=>{}}, "chalk"=>{:version=>"1.1.3", :parent=>"gulp", :dependencies=>{"ansi-styles"=>{:version=>"2.2.1", :parent=>"chalk", :dependencies=>{}}}}}}}
#list = {"gulp"=>{:version=>"3.9.1", :parent=>"_root", :dependencies=>{}}}
#list = {"gulp"=>{:version=>"3.9.1", :parent=>"_root", :dependencies=>{"archy"=>{:version=>"1.0.0", :parent=>"gulp", :dependencies=>{}}, "chalk"=>{:version=>"1.1.3", :parent=>"gulp", :dependencies=>{"ansi-styles"=>{:version=>"2.2.1", :parent=>"chalk", :dependencies=>{}}, "escape-string-regexp"=>{:version=>"1.0.5", :parent=>"chalk", :dependencies=>{}}, "has-ansi"=>{:version=>"2.0.0", :parent=>"chalk", :dependencies=>{"ansi-regex"=>{:version=>"2.1.1", :parent=>"has-ansi", :dependencies=>{}}}}, "strip-ansi"=>{:version=>"3.0.1", :parent=>"chalk", :dependencies=>{"ansi-regex"=>{:version=>"2.1.1", :parent=>"strip-ansi", :dependencies=>{}}}}, "supports-color"=>{:version=>"2.0.0", :parent=>"chalk", :dependencies=>{"has-flag"=>{:version=>"1.0.0", :parent=>"supports-color", :dependencies=>{}}}}}}, "deprecated"=>{:version=>"0.0.1", :parent=>"gulp", :dependencies=>{}}, "gulp-util"=>{:version=>"3.0.8", :parent=>"gulp", :dependencies=>{"array-differ"=>{:version=>"1.0.0", :parent=>"gulp-util", :dependencies=>{}}, "array-uniq"=>{:version=>"1.0.3", :parent=>"gulp-util", :dependencies=>{}}, "beeper"=>{:version=>"1.1.1", :parent=>"gulp-util", :dependencies=>{}}}}}}}

require './history.rb'
require './download.rb'
require './dependency.rb'
require './version.rb'
require './jsonobject.rb'

#p NPKG::Parent.new("ansi-styles",list).walk("mega")
