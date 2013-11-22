require 'bilibili_sunday/cacher'

module BilibiliSunday

	class Downloader

		require 'fileutils'
		require 'yaml'
		require 'digest/md5'
		require 'aria2'
		require 'nokogiri'
		require 'xmlsimple'
		require 'uri'
		require 'open-uri'
		require 'logger'

		def initialize(work_path, downloader = nil, logger = nil)
			FileUtils.mkdir_p(work_path)

			@work_path = File.expand_path(work_path)
			@downloader = downloader || Aria2::Downloader.new
			@logger = logger || Logger.new($stdout)
			@cacher = BilibiliSunday::Cacher.new(cacher_store_path)
		end

		def routine_work
			@logger.info 'Carrying out routine work. '

			videos = all_videos

			videos.each do |cid|
				update_status(cid)
				concat(cid) if (cache_completed?(cid) && (!concat_started?(cid)))
			end
		end

		def query_status(cid)
			status = :unknown
			status = :caching if cache_in_progress?(cid)
			status = :concatenating if concat_in_progress?(cid)
			status = :complete if concat_completed?(cid)

			{
				cid: cid,
				status: status, 
				downloads: load_yaml(status_yaml_path(cid)) || [], 
				path: concat_completed?(cid) ? concat_output_file_path(cid) : nil
			}
		end

		def request_cache(cid)
			cache(cid)
		end

		def all_videos
			Dir.glob(File.join(video_store_path, '*')).select {|f| File.directory? f}.map { |f| File.basename(f).to_i }
		end

		def cid_for_video_url(url)
			doc = Nokogiri::HTML(gzip_inflate(@cacher.read_url(url)))

			doc.css('.scontent').each do |i|
				res = /cid=([0-9]*)/.match(i.to_s)

				if res && res[1]
					return res[1].to_i
				else
					raise "Not a valid Bilibili video page URL. "
				end
			end

			raise "Not a valid Bilibili video page URL. "
		end

		def active_videos
			all_videos.select { |i| !concat_completed?(i)}
		end

		private

			def gzip_inflate(string)
				# TODO Ugly workaround... 
			    begin
			      Zlib::GzipReader.new(StringIO.new(string)).read
			    rescue
			      string
			    end
			end

			def update_status(cid)
				# If download has not started yet, skip updating status. 
				return unless cache_started?(cid)

				# If download already completed, skip updating status. 
				return if cache_completed?(cid)

				downloads = load_yaml(downloads_yaml_path(cid))
				old_status = load_yaml(status_yaml_path(cid))

				status = []
				incomplete = false

				downloads.each_with_index do |download, order|
					# If already completed, stop updating status. 
					if old_status
						last_status = old_status[order][:status]
						if last_status['status'] == 'complete'
							download[:status] = last_status
							status << download
							next
						end
					end

					download[:status] = @downloader.query_status(download[:download_id])
					incomplete = true unless download[:status]['status'] == 'complete'
					status << download
				end

				write_yaml(status_yaml_path(cid), status)
				mark_cache_complete(cid) unless incomplete
			end

			def load_yaml(path)
				File.exists?(path) ?
					YAML.load(File.open(path) { |f| f.read }) :
					nil
			end

			def write_yaml(path, obj)
				FileUtils.mkdir_p(File.dirname(path))
				File.open(path, 'w') { |f| f.write(YAML.dump(obj))}
			end

			def yaml_exists?(rel_path)
				File.exists?(rel_path)
			end

			def fetch_filelist(cid)
				url = "http://interface.bilibili.tv/v_cdn_play?cid=#{cid}"
				xml = XmlSimple::xml_in(@cacher.read_url(url))

				filelist = [''] * xml['durl'].length

				xml['durl'].each do |file|
					order = file['order'][0].to_i
					url = file['url'][0]
					filelist[order - 1] = url
				end

				filelist
			end

			def mark_cache_complete(cid)
				write_yaml(downloaded_yaml_path(cid), true)
			end

			def mark_concat_complete(cid)
				write_yaml(concatenated_yaml_path(cid), true)
			end

			def video_store_path
				File.join(@work_path, "store")
			end

			def video_path(cid)
				File.join(video_store_path, "#{cid}")
			end

			def cache_started?(cid)
				yaml_exists?(downloads_yaml_path(cid))
			end

			def cache_completed?(cid)
				yaml_exists?(downloaded_yaml_path(cid))
			end

			def cache_in_progress?(cid)
				cache_started?(cid) && (!cache_completed?(cid))
			end

			def concat_started?(cid)
				yaml_exists?(ffmpeg_concat_input_path(cid))
			end

			def concat_completed?(cid)
				yaml_exists?(concatenated_yaml_path(cid))
			end

			def concat_in_progress?(cid)
				concat_started?(cid) && (!concat_completed?(cid))
			end

			def downloads_yaml_path(cid)
				File.join(video_path(cid), 'downloads.yml')
			end

			def downloaded_yaml_path(cid)
				File.join(video_path(cid), 'downloaded.yml')
			end

			def concatenated_yaml_path(cid)
				File.join(video_path(cid), 'concatenated.yaml') 
			end

			def cacher_store_path
				File.join(@work_path, 'cache')
			end

			def video_ext(cid)
				# TODO better way of identifying file types
				downloads = load_yaml(downloads_yaml_path(cid))
				ext = File.extname(downloads[0][:path])
				ext && !ext.empty? ?
					ext :
					'.flv'
			end

			def fix_extname(extname)
				return '.flv' if extname == '.hlv'
				extname
			end

			def concat_output_file_path(cid)
				File.join(video_path(cid), "entirety#{video_ext(cid)}")
			end

			def status_yaml_path(cid)
				File.join(video_path(cid), 'status.yaml')
			end

			def ffmpeg_concat_input_path(cid)
				File.join(video_path(cid), 'concat_list')
			end

			def cache(cid)
				return false if cache_started?(cid)

				FileUtils.mkdir_p(video_path(cid))

				filelist = fetch_filelist(cid)
				downloads = []

				filelist.each_with_index do |url, order|
					to_name = "#{order}#{fix_extname(File.extname(URI.parse(url).path))}"
					to_path = File.join(video_path(cid), to_name)

					downloads << {
						order: order, 
						url: url, 
						download_id: @downloader.download(url, to_path), 
						path: to_path
					}
				end

				write_yaml(downloads_yaml_path(cid), downloads)

				true
			end

			def write_ffmpeg_concat_input_file(cid)
				downloads = load_yaml(downloads_yaml_path(cid))

				File.open(ffmpeg_concat_input_path(cid), 'w') do |f|
					downloads.sort_by! { |f| f[:order] }

					downloads.each do |v|
						f.puts "file '#{v[:path]}'"
					end
				end
			end

			def remove_ffmpeg_concat_input_file(cid)
				FileUtils.rm(ffmpeg_concat_input_path(cid))
			end

			def concat(cid)
				return false if concat_started?(cid)

				unless cache_completed?(cid) 
					raise "Cannot concat clips. Downloads not completed. "
				end

				write_ffmpeg_concat_input_file(cid)

				Thread.start(cid) do |cid|
					ffmpeg = "ffmpeg"
					command = "\"#{ffmpeg}\" -f concat -i \"#{ffmpeg_concat_input_path(cid)}\" -c copy \"#{concat_output_file_path(cid)}\""

					system(command)

					if $? == 0
						mark_concat_complete(cid)
					else
						remove_ffmpeg_concat_input_file(cid)
					end
				end

			end

	end

end