module NPKG
	class Tree
		def initialize(pkg,version=nil)
			@pkg = pkg
			@json = NPKG::Download.get(@pkg)
			@version = NPKG::History.new(@pkg).has?(version) ? version : NPKG::History.new(@pkg).last
		end

		def generate(parent=nil,pkg=@pkg,version=@version,mega={})
			parent ||= "_root"
			dependencies = NPKG::Dependency.new(pkg).dependencies

			if mega.empty?
				mega[pkg] = {:version=>version, :parent=>parent, :dependencies=>{}}
				dependencies.each do |k,v|
					generate(pkg,k,v,mega)
				end
			else
				unless NPKG::JSONObject.new(mega).has?(pkg)
					walker = eval(NPKG::Parent.new(parent,mega).walk("mega"))
					walker[pkg] = {:version=>version, :parent=>parent, :dependencies=>{}}
					unless dependencies.nil?
						dependencies.each do |k,v|
							generate(pkg,k,v,mega)
						end
					end
				end
			end

			return mega
		end
	end
end

require './download.rb'
require './history.rb'
require './version.rb'
require './dependency.rb'
require './parent.rb'

list = {"gulp"=>{:version=>"3.9.1", :parent=>"_root", :dependencies=>{"archy"=>{:version=>"1.0.0", :parent=>"gulp", :dependencies=>{}}, "chalk"=>{:version=>"1.1.3", :parent=>"gulp", :dependencies=>{}}}}}


p NPKG::Tree.new("gulp").generate
