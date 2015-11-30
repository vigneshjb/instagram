require 'rubygems'
require 'json'
require 'uri'
require 'net/http'

base_url = "api.instagram.com"
following_path = "/v1/users/self/follows"
followed_by_path = "/v1/users/self/followed-by"
access_token = ""

following_url = URI::HTTPS.build({:host => base_url, :path => following_path, :query => {:access_token => access_token}.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join("&")}).to_s
followed_by_url = URI::HTTPS.build({:host => base_url, :path => followed_by_path, :query => {:access_token => access_token}.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join("&")}).to_s

def make_http_request(url)
	begin
		uri = URI.parse(url)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Get.new(uri.request_uri)
		response = http.request(request)
	rescue => e
		puts "Error: makig an HTTP request :"+e.to_s
	end
	JSON.parse(response.body, :symbolize_names=>true) || {}
end

def fetch_paginated_data(url)
	result_set = make_http_request(url)
	result_set.delete(:meta)
	while result_set[:pagination]!=nil && result_set[:pagination][:next_url]!=nil
		to_append = make_http_request(result_set[:pagination][:next_url])
		to_append[:data].each{|post| result_set[:data].push(post)}
		result_set.delete(:pagination)
		if (to_append[:pagination]!=nil)
			result_set[:pagination] = to_append[:pagination]
		end
	end
	result_set.delete(:pagination)
	result_set
end

following_data_hash = fetch_paginated_data(following_url)
followed_by_data_hash = fetch_paginated_data(followed_by_url)

puts "Number of people I follow is  : #{following_data_hash[:data].length}"
puts "Number of people following me is : #{followed_by_data_hash[:data].length}"

File.open("follow", 'w') { |file| file.write(JSON.pretty_generate(following_data_hash)) }
File.open("followed_by", 'w') { |file| file.write(JSON.pretty_generate(followed_by_data_hash)) }

following_id_hash = {}
followed_by_id_hash = {}

following_data_hash[:data].each { |entry|
	following_id_hash[entry[:id]] = entry
}

followed_by_data_hash[:data].each { |entry|
	followed_by_id_hash[entry[:id]] = entry
}

i_follow_they_dont = {}
they_follow_i_dont = {}

following_id_hash.each { |k,v| 
	if (followed_by_id_hash[k] == nil)
		i_follow_they_dont[k] = v
	end
}

followed_by_id_hash.each { |k,v| 
	if (following_id_hash[k] == nil)
		they_follow_i_dont[k] = v
	end
}


File.open('result', 'w') { |file| 
	puts "Number of people whom I follow but they dont follow me : #{i_follow_they_dont.length}"
	file.write("Number of people whom I follow but they dont follow me :\n")
	i_follow_they_dont.each{ |k,v|
		file.write(JSON.pretty_generate(v))
		file.write("\n")
	}
	file.write("\n\n\n")
	puts "Number of people who follow me but I dont follow them : #{they_follow_i_dont.length}"
	file.write("Number of people who follow me but I dont follow them : \n")
	they_follow_i_dont.each{ |k,v|
		file.write(JSON.pretty_generate(v))
		file.write("\n")
	}
}

