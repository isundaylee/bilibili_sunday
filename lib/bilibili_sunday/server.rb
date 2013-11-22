require 'bilibili_sunday/downloader'
require 'webrick'

module BilibiliSunday

	require 'base64'
	require 'json'

	class RequestHandler

		def initialize(downloader)
			@downloader = downloader
		end

		def handle_request(method, params)
			begin
				result = /^bilibili_sunday.(.*?)$/.match(method)

				return handle_error(1, 'No matching method. ') unless result

				method = result[1]

				if method == 'cid_for_video_url'
					handle_cid_for_video_url(params[0])
				elsif method == 'request_cache'
					handle_request_cache(params[0].to_i)
				elsif method == 'query_status'
					handle_query_status(params[0].to_i)
				elsif method == 'all_videos'
					handle_all_videos
				elsif method == 'active_videos'
					handle_active_videos
				else
					handle_error(1, 'No matching method. ')
				end
			# rescue
				# return handle_error(2, 'Internal server error. ')
			end
		end

		def handle_cid_for_video_url(url)
			return 200, {result: @downloader.cid_for_video_url(url)}
		end

		def handle_request_cache(cid)
			return 200, {result: @downloader.request_cache(cid)}
		end

		def handle_query_status(cid)
			return 200, {result: @downloader.query_status(cid)}
		end

		def handle_all_videos
			return 200, {result: @downloader.all_videos}
		end

		def handle_active_videos
			return 200, {result: @downloader.active_videos}
		end

		def handle_error(error_code, error_message)
			return 500, {error: {code: error_code, message: error_message}}
		end

	end

	class Servlet < WEBrick::HTTPServlet::AbstractServlet

		def initialize(server, downloader)
			super(server)
			@handler = RequestHandler.new(downloader)
		end

		def do_GET(request, response)
			id = request.query["id"]
			method = request.query["method"]
			params = JSON.parse(Base64.decode64(request.query["params"]))

			code, result = @handler.handle_request(method, params)
			result[:id] = id
			result[:jsonrpc] = '2.0'

			response.status = code
			response['Content-Type'] = 'application/json'
			response.body = result.to_json
		end

	end

	class Server

		require 'json'

		DEFAULT_PORT = 10753

		def initialize(port = DEFAULT_PORT, working_dir = nil)
			@port = port
			@downloader = Downloader.new(working_dir || File.expand_path("~/.bilibili_sunday"))
		end

		def start
			@running = true

			@downloader_thread = Thread.new do
				while true
					@downloader.routine_work
					sleep 1
				end
			end

			@rpc_server_thread = Thread.new do
				begin
					server = WEBrick::HTTPServer.new(:Port => @port)
					server.mount "/jsonrpc", Servlet, @downloader
					server.start
				rescue
				ensure
					server.shutdown
				end
			end

			while true
				unless @running
					@downloader_thread.terminate
					@rpc_server_thread.terminate
					break
				end
				sleep 1
			end
		end

		def stop
			@running = false
		end

	end

end