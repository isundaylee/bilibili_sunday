require 'bilibili_sunday'

module BilibiliSunday

	require 'base64'
	require 'json'

	class Client

		DEFAULT_HOST = '127.0.0.1'
		DEFAULT_PORT = 10753

		def initialize(host = DEFAULT_HOST, port = DEFAULT_PORT, working_dir = nil)
			@host = host
			@port = port
		end

		def cid_for_video_url(url)
			rpc_call('cid_for_video_url', [url])
		end

		private

			def get(url, params = {})
				uri = URI.parse(url)

				uri.query = URI.encode_www_form(params)

				http = Net::HTTP.new(uri.host, uri.port)
				request = Net::HTTP::Get.new(uri.request_uri)

				response = http.request(request)

				{
					'code' => response.code.to_i, 
					'body' => response.body
				}
			end

			def rpc_path
				"http://#{@host}:#{@port}/jsonrpc"
			end

			def rpc_call(method, params)
				method = "bilibili_sunday.#{method}"
				id = 'bilibili_sunday_client'
				params_encoded = Base64.encode64(JSON.generate(params))

				response = get("#{rpc_path}", {'method' => method, 'id' => id, 'params' => params_encoded})
				answer = JSON.parse(response['body'])

				if response['code'] == 200
					answer['result']
				else
					raise "BilibiliSunday Server error #{answer['error']['code'].to_i}: #{answer['error']['message']}"
				end
			end

	end

end