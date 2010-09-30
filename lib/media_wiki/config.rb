require 'optparse'
require 'yaml'

module MediaWiki
  
  class Config
    
    attr_reader :article, :desc, :file, :pw, :summary, :target, :url, :user
    
    def initialize(args, type = "read")
      @summary = "Automated edit via MediaWiki::Gateway"
      @opts = OptionParser.new do |opts|
        opts.banner = "Usage: [options]"
        
        opts.on("-h", "--host HOST", "Use preconfigured HOST in config/hosts.yml") do |host_id|
          yaml = YAML.load_file('config/hosts.yml')
          if yaml.include? host_id
            host = yaml[host_id]
            @url = host['url']
            @pw = host['pw']
            @user = host['user']
          else
            raise "Host #{host_id} not found in config/hosts.yml"
          end
        end

        if type == "upload"
          opts.on("-d", "--description DESCRIPTION", "Description of file to upload") do |desc|
            @desc = desc
          end
          opts.on("-t", "--target-file TARGET-FILE", "Target file name to upload to") do |target|
            @target = target
          end
        else
          opts.on("-a", "--article ARTICLE", "Name of article in Wiki") do |article|
            @article = article
          end
        end
        
        opts.on("-n", "--username USERNAME", "Username for login") do |user|
          @user = user
        end

        opts.on("-p", "--password PASSWORD", "Password for login") do |pw|
          @pw = pw
        end

        if type != "read"
          opts.on("-s", "--summary SUMMARY", "Edit summary for this change") do |summary|
            @summary = summary
          end
        end

        opts.on("-u", "--url URL", "MediaWiki API URL") do |url|
          @url = url
        end
      end
      @opts.parse!
      abort("URL (-u) or valid host (-h) is mandatory.") unless @url
    end

    def abort(error)
      puts "Error: #{error}\n\n#{@opts.to_s}"
      exit
    end

  end
end

