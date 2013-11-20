module BilibiliSunday

	class Downloader

		require 'fileutils'
		require 'yaml'
		require 'digest/md5'
		require 'aria2'
		require 'nokogiri'
		require 'xmlsimple'
		require 'uri'

		def initialize(work_path, downloader = nil)
			FileUtils.mkdir_p(work_path)

			@work_path = File.expand_path(work_path)
			@downloader = downloader || Aria2::Downloader.new
		end

		private

			def load_yaml(rel_path)
				File.exists?(File.join(@work_path, rel_path)) ?
					YAML.load(File.open(File.join(@work_path, rel_path)) { |f| f.read }) :
					nil
			end

			def write_yaml(rel_path, obj)
				FileUtils.mkdir_p(File.dirname(File.join(@work_path, rel_path)))
				File.open(File.join(@work_path, rel_path), 'w') { |f| f.write(YAML.dump(obj))}
			end

			def yaml_exists?(rel_path)
				File.exists?(File.join(@work_path, rel_path))
			end

			def fetch_filelist(cid)
				url = "http://interface.bilibili.tv/v_cdn_play?cid=#{cid}"
				xml = XmlSimple::xml_in(open(url).read)

				filelist = [''] * xml['durl'].length

				xml['durl'].each do |file|
					order = file['order'][0].to_i
					url = file['url'][0]
					filelist[order - 1] = url
				end

				filelist
			end

			def video_path_for(cid)
				File.join(@work_path, "store/#{cid}")
			end

			def cache_started?(cid)
				yaml_exists?(downloads_yaml_path(cid))
			end

			def cache_completed?(cid)
				yaml_exists?(downloaded_yaml_path(cid))
			end

			def concat_completed?(cid)
				yaml_exists?(concat_yaml_path(cid))
			end

			def downloads_yaml_path(cid)
				File.join(video_path_for(cid), 'downloads.yml')
			end

			def downloaded_yaml_path(cid)
				File.join(video_path_for(cid), 'downloaded.yml')
			end

			def concat_yaml_path(cid)
				File.join(video_path_for(cid), 'concat.yaml') 
			end

			def cache(cid)
				return false if cache_started?(cid)

				FileUtils.mkdir_p(video_path_for(cid))

				filelist = fetch_filelist(cid)
				downloads = []

				filelist.each_with_index do |url, order|
					to_name = "#{order}#{File.extname(URI.parse(url).path)}"
					to_path = File.join(video_path_for(cid), to_name)

					downloads << {
						order: order, 
						url: url, 
						download_id: @downloader.download(url, to_path), 
					}
				end

				write_yaml(downloads_yaml_path(cid), downloads)

				true
			end

		public

			def concat(cid)
				return false if concat_completed?(cid)

				unless cache_completed?(cid) 
					raise "Cannot concat clips. Downloads not completed. "
				end
			end

	end

end