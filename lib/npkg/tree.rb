module NPKG
	class Tree
		def initialize(pkg,version)
			@pkg = pkg
			@json = NPKG::Download.get(@pkg)
			@version = NPKG::History.new(@pkg).has?(version) ? version : NPKG::History.new(@pkg).last
		end

		def generate(exclusion={},parent=nil,parentversion=nil, pkg=@pkg,version=@version,mega={})
			parent ||= "_root"
			parentversion ||= "0.0.0"
			dependencies = NPKG::Dependency.new(pkg).dependencies

			if mega.empty?
				mega[pkg] = {:version=>version, :parent=>parent, :parentversion=>parentversion, :dependencies=>{}}
				unless dependencies.nil?
					dependencies.each do |k,v|
						generate(exclusion,pkg,version,k,v,mega)
					end
				end
			else
				unless NPKG::JSONObject.new(mega).has?(pkg,version)
					# occur the first time, so apply exclusion here.
					# we need to escape for some dependencies to allow package split.
					unless NPKG::Exclusion.new(exclusion).exclude?(pkg,version)
						walker = eval(NPKG::Parent.new(parent,parentversion,mega).walk("mega"))
						walker[pkg] = {:version=>version, :parent=>parent, :parentversion=>parentversion, :dependencies=>{}}
						unless dependencies.nil?
							dependencies.each do |k,v|
								generate(exclusion,pkg,version,k,v,mega)
							end
						end
					end
				else
					# This indicates we have at least two modules rely on the same dependency
					# usually we keep the shortest path, so we put this dependency under the
					# same parent of those two modules.
					parents_old = NPKG::Parent.new(pkg,version,mega).parents
					parents_new = NPKG::Parent.new(parent,parentversion,mega).parents
					parents_new << parent # form parents for the same pkg
					intersected = intersect(parents_old,parents_new)

					oldparent = parents_old[-1]
					oldparentversion = eval(get_version("mega",parents_old))
					newparent = intersected[-1]
					newparentversion = eval(get_version("mega",intersected))

					# we need to insert the new one and delete the old one.
					unless intersected.empty? # already been processed and moved.
						eval(NPKG::Parent.new(oldparent,oldparentversion,mega).walk("mega")).delete(pkg)
						eval(NPKG::Parent.new(newparent,newparentversion,mega).walk("mega"))[pkg] = {:version=>version, :parent=>newparent, :parentversion=>newparentversion,:dependencies=>{}}
					end

					unless dependencies.nil?
						dependencies.each do |k,v|
							generate(exclusion,pkg,version,k,v,mega)
						end
					end
				end
			end

			return mega
		end

		private

		def get_version(str,arr)
			if arr.size > 1
				for i in 1..(arr.size - 1) do
					if i == arr.size - 1
						str << "[\"#{arr[i]}\"][:version]"
					else
						str << "[\"#{arr[i]}\"][:dependencies]"
					end
				end
			end
			return str
		end

		def intersect(arr1,arr2)
			# ["_root", "gulp", ..., "is-descriptor", "lazy-cache"]
			# ["_root", "gulp", ..., "collection-visit", "lazy-cache"]
			# we need to stip "lazy-cache" from the intersected array.
			# because it is also a multi-occured pkg that needs to process later.
			# keeping it will lead to an invalid walk path.
			long = []
			short = []

			if arr1.size - arr2.size > 0
				long = arr1.reverse
				short = arr2.reverse
			elsif arr1.size - arr2.size == 0
				long = arr1.reverse
				short = arr2.reverse
			else
				long = arr2.reverse
				short = arr1.reverse
			end

			count = 0
			for i in 0..(long.size - 1) do
				unless short[i].nil?
					if long[i] == short[i]
						count = count + 1
					else
						break # break if meet the fisrt unmatch
					end
				end
			end

			if count > 0
				return (arr1 & arr2)[0..((-1)*count - 1)]
			else
				return arr1 & arr2
			end
		end
	end
end
