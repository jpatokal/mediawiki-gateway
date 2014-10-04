require 'optparse'
require 'yaml'

module MediaWiki

  class Config

    attr_reader :article, :desc, :file, :pw, :summary, :target, :url, :user

    def initialize(args, type = 'read')
      @summary = 'Automated edit via MediaWiki::Gateway'

      @opts = OptionParser.new { |opts|
        opts.banner = 'Usage: [options]'

        opts.on('-h', '--host HOST', 'Use preconfigured HOST in config/hosts.yml') { |host_id|
          host = YAML.load_file('config/hosts.yml').fetch(host_id) {
            raise "Host #{host_id} not found in config/hosts.yml"
          }

          @url, @pw, @user = host.values_at(*%w[url pw user])
        }

        if type == 'upload'
          opts.on('-d', '--description DESCRIPTION', 'Description of file to upload') { |desc|
            @desc = desc
          }

          opts.on('-t', '--target-file TARGET-FILE', 'Target file name to upload to') { |target|
            @target = target
          }
        else
          opts.on('-a', '--article ARTICLE', 'Name of article in Wiki') { |article|
            @article = article
          }
        end

        opts.on('-n', '--username USERNAME', 'Username for login') { |user|
          @user = user
        }

        opts.on('-p', '--password PASSWORD', 'Password for login') { |pw|
          @pw = pw
        }

        if type != 'read'
          opts.on('-s', '--summary SUMMARY', 'Edit summary for this change') { |summary|
            @summary = summary
          }
        end

        opts.on('-u', '--url URL', 'MediaWiki API URL') { |url|
          @url = url
        }
      }

      @opts.parse!

      abort 'URL (-u) or valid host (-h) is mandatory.' unless @url
    end

    def abort(error)
      puts "Error: #{error}\n\n#{@opts.to_s}"
      exit
    end

  end

end
