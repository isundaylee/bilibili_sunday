module BilibiliSunday

	class Cacher

		require 'fileutils'
		require 'open-uri'
		require 'digest/md5'

		def initialize(dir)
			@dir = dir

			FileUtils.mkdir_p(@dir)
		end

		def read_url(url)
			cached?(url) ?
				cached_content(url) :
				write_cache_for_url(url, open(url).read)
		end

		private 

			def cached?(url)
				File.exists?(cache_path_for_url(url))
			end

			def cached_content(url)
				File.open(cache_path_for_url(url)) { |f| f.read }
			end

			def write_cache_for_url(url, content)
				File.open(cache_path_for_url(url), 'w') { |f| f.write(content) }
				content
			end

			def cache_path_for_url(url)
				File.join(@dir, Digest::MD5.hexdigest(url))
			end

	end

end