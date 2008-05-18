#!ruby
 #!/usr/local/bin/ruby -rubygems
require 'camping'
require 'open-uri'
require 'rexml/document'
require 'uri'
#require 'memcache'

#= Setup
#   $ sudo gem camping
#= Run
#  $ cd ./gadget-server
#  $ camping gadget.rb
#  ..
#  $ open http://0.0.0.0:3301/gadget?url=http://doc.examples.googlepages.com/magic-decoder.xml

Camping.goes :Gadget

module Cache
  class Store
    class << self
      def put(url, value)
        file = "cache/#{keyify(url)}"
        File.open(file, 'w') do |f|
          f.write(value)
        end
      end
      
      def get(url)
        cache = ""
        file = "cache/#{keyify(url)}"
        return "" unless File.exist? file
        File.open(file, 'r') do |f|
          cache = f.read
        end
      end
      
      def keyify(url)
        uri = URI.parse(url)
        "#{uri.host}#{uri.path.tr('/', '_')}"
      end
    end
  end
end

module Gadget::Controllers
  
  class Server < R '/gadget_data'
     def get
       @url = @input[:url] 
       @cached = @input[:cached]
       @content_data = ""
       @content = ""
       
       #1 Fetch content from cache
       @content = Cache::Store.get(@url) if @cached != nil && @cached != "false"
       
       if @content == nil || @content == ""
         #2 Fetch the xml
         open(@url) do |file|
          @xml = file.read
         end
       
         #3 Parse the xml
         doc = REXML::Document.new(@xml)
         doc.elements.each('Module/Content') do |c|
            c.texts.each do |text|
              @content_data += text.to_s
            end
         end
       
         doc.elements.each('Module/ModulePrefs') do |c|
             @title = c.attributes["title"]
          end
       
        # TODO - parse via spec http://code.google.com/apis/gadgets/docs/spec.html#compliance 
        # ...
        # ...
       
         #4 Build the content
         @content = <<-"CONTENT"
          <html>
          	<head>
          	<style type="text/css"></style>
          	</head>
          	<body>
          	  <script src="http://code.google.com/ig/extern_js/f/CgJlbhICdXMrMAE4ACw/_Ky-X_zR8Mc.js" />
          	  <script>
          	      function sendRequest(iframe_id, service_name, args_list, remote_relay_url,callback, local_relay_url) 
          	      {
          	        _IFPC.call(iframe_id, service_name, args_list, remote_relay_url, callback,local_relay_url);
          	      }
                  var gv = gadgets.views;
                  gv.requestNavigateTo = gv.getCurrentView = gv.getParams = errFunc;
              </script>
              <script>_et="";_IG_Prefs._parseURL("0");</script>
              <script>_IG_Prefs._addAll("0", [["up_.lang","en"],["up_.country","us"],["up_synd","open"]]);</script>
          		<div style="border: 0pt none ; margin: 0pt; padding: 0pt; overflow: hidden; width: 100%; height: auto;"> 
          		#{@content_data}
          		</div>
          	</body>
          </html>
         CONTENT
       
         #5 Cache the content
         Cache::Store.put(@url, @content)
       end
       
       #6 Render the content
       if @url
         render :gadget_data
       else
         render :no_gadget
       end
     end
  end
  
  ### Creates a gadget ###
  class Widget < R '/gadget'
    def get
      @url = @input[:url]
      @cached = @input[:cached]
      @domain = "0.0.0.0:3301"
      #@domain = "10.8.9.35:3301"
      
      render :gadget
    end
  end

  class Page < R '/(\w+)'
    def get(page_name)
      @p = page_name
      render :no_page
    end
  end

end

module Gadget::Views

  def gadget
    div :style => "width: 250px; height: 250px" do
      h4 @title 
      iframe :src => "http://#{@domain}/gadget_data?url=#{@url}&cached=#{@cached}", 
        :frameborder => 0, 
        :style => "border: 0pt none ; margin: 0pt; padding: 0pt; overflow: hidden; width: 100%; height: 100%;"
    end
  end
  
  def gadget_data
    @content
  end

  def no_gadget
    h1 'No Gadget URL specified'
    h2 'Please pass /gadget?url={gadget path}'
  end
  
  def no_page
    h1 "Page '#{@p}' was not found!"
    h2 'Please verify that you have the correct URL'
  end
  
end
