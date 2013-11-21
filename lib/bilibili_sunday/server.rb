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
				else
					handle_error(1, 'No matching method. ')
				end
			rescue
				return handle_error(2, 'Internal server error. ')
			end
		end

		def handle_cid_for_video_url(url)
			return 200, {result: BilibiliSunday::Downloader.cid_for_video_url(url)}
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
			begin
				server = WEBrick::HTTPServer.new(:Port => @port)
				server.mount "/jsonrpc", Servlet, @downloader
				trap('INT'){ server.shutdown }
				server.start
			rescue
			ensure
				server.shutdown
			end
		end

	end

end