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
#  $ open http://0.0.0.0:3301/gadget_data?url=http://doc.examples.googlepages.com/magic-decoder.xml&inline=true
#  $ open http://0.0.0.0:3301/gadget?url=http://doc.examples.googlepages.com/breakfast-menu.xml&mid=20

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


module Template
  class Html
    class << self
      def build(content_data)
        content = <<-"CONTENT"
         <html>
         	<head>
         	<style type="text/css"></style>
         	</head>
         	<body>
         	  <script src="http://www.google.com/ig/extern_js/f/CgJlbhICdXMrMAE4ACw/LuEUfb0hR1Q.js" />
         	  <script>
         	      function sendRequest(iframe_id, service_name, args_list, remote_relay_url,callback, local_relay_url) 
         	      {
         	        _IFPC.call(iframe_id, service_name, args_list, remote_relay_url, callback,local_relay_url);
         	      }
                 var gv = gadgets.views;
                 gv.requestNavigateTo = gv.getCurrentView = gv.getParams = errFunc;
             </script>
             <script>_et="";_IG_Prefs._parseURL("0");</script>
             <script>
              _IG_Prefs._addAll("0", [["up_mycalories","800"],["up_mychoice","0"],["up_.lang","en"],["up_.country","us"],["up_synd","open"]]);
             </script>
         		<div style="border: 0pt none ; margin: 0pt; padding: 0pt; overflow: hidden; width: 100%; height: auto;"> 
         		#{content_data}
         		</div>
         		<script>
              _IG_TriggerEvent("domload");
            </script>
         	</body>
         </html>
        CONTENT
      end
    end
  end
end    

module Gadget::Controllers
  
  class Server < R '/gadget_data'
     def get
       @url = @input[:url] 
       @inline = @input[:inline]
       @nocache = @input[:nocache]
       
       #Hangman variables
       @module_id = @input[:mid]
       
       @content_data = ""
       @content = ""
       
       #1 Fetch content from cache
       @content = Cache::Store.get(@url) unless @nocache == "true"
       
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
       
       
        #3.1 Hangman variables
        @content_data = @content_data.sub('__MODULE_ID__', @module_id) unless @module_id == nil
       
        # TODO - parse via spec http://code.google.com/apis/gadgets/docs/spec.html#compliance 
        # ...
        # ...
       
         #5 Cache the content
         Cache::Store.put(@url, @content_data)
         
         @content = @content_data
       end
       
       #6 Template the content
       unless @inline != nil && @inline == "true"
         @content = Template::Html.build(@content)
       end
       
       #7 Render the content
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
      @nocache = @input[:nocache]
      @module_id = @input[:mid]
      @domain = "0.0.0.0:3301"
      #@domain = "10.8.9.35:3301"
      
      render :gadget
    end
  end
  
  class Json < R '/ig/jsonp' #'/ig/feedjson 
    def get
      @url = @input[:url]

      @json = "throw 1; < don't be evil' >{'#{@url}' : { 'body' : '#{self.fetchXml(@url)}' ,'rc': 200 }}"
       
      render :json
    end
    
    def post
      @url = @input[:url]
      
      @json = "throw 1; < don't be evil' >{'#{@url}' : { 'body' : '#{self.fetchXml(@url)}' ,'rc': 200 }}"
       
      render :json
    end
    
    private
    def fetchXml(url)
      open(url) do |file|
        @xml = file.read
       end
       
       escaped = @xml.gsub('<', '\\x3c').gsub('>', '\\x3e').gsub('=', '\\x3d').gsub('"', '\\x22')
       
       data = ""
       
       escaped.each {|l| data += l.chomp}
       
       return data
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
      iframe :src => "http://#{@domain}/gadget_data?url=#{@url}&nocache=#{@nocache}&mid=#{@module_id}", 
        :frameborder => 0, 
        :style => "border: 0pt none ; margin: 0pt; padding: 0pt; overflow: hidden; width: 100%; height: 100%;"
    end
  end
  
  def gadget_data
    @content
  end
  
  def json
    @json
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
