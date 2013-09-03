module Crawler
	class Curl
		extend Forwardable

		CALLBACK = ['on_success', 'on_failure', 'on_complete', 'on_body', 'on_header']
		SUCCESS = 'success'
		FAILURE = 'failure'

		attr_accessor :parser_data, :async
		attr_reader :callbacks, :parser, :behavior

		def_delegators :@obj, :useragent, :max_redirects, :timeout, :autoreferer,
													:follow_location, :body_str
		def_delegators :@obj, :on_success, :on_failure, :on_complete, :on_body, :on_header

		def initialize(url, opts=nil)
			@callbacks = []
			@parser_data = {}
			send('instance=', url, opts)
		end

		def instance
			@obj
		end

		def instance=(url, opts=nil)
			if url.instance_of? String
				@obj = ::Curl::Easy.new(url)
				Crawler.set_config(@obj, opts || Crawler.config.curl_easy)
			else
				@obj = url
			end
			@html = nil
			set_callbacks
		end

		def html
			@html ||= Nokogiri::HTML(body_str)
		end

		def url
			instance.last_effective_url
		end

		def perform
			Crawler::Async.new.add_entry(self) if @async.blank?
			@async.perform
		end

		def callbacks=(args)
			raise TypeError unless args.length != 0 && args.all?{|arg| arg.is_a? Method}
			@callbacks = args
			set_callbacks
		end

		def parser=(p)
			(p <= Crawler::Strategy) ? @parse = p : raise(TypeError)
		end

		def behavior=(b)
			b.instance_of?(Symbol) ? @behavior = b : raise(TypeError)
		end

		def status
			@status || FAILURE
		end

		private
		def create_proc(arg, index)
			if index == 0
				Proc.new do |data|
					if parse
						@status = SUCCESS
						arg.call(self) if arg.present?
					end
				end
			elsif arg.present?
				Proc.new {|data| arg.call(data)}
			end
		end

		def parse
			@parser.present? ? @parser.parse(self) : Crawler.parse(self)
		end

		def set_callbacks
			Crawler::Curl::CALLBACK.each_with_index do |cb_name, index|
				proc = create_proc(@callbacks[index], index)
				if proc.present?
					instance.send("#{cb_name}", &proc)
				end
			end
		end
	end
end
