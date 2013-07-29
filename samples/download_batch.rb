require './lib/media_wiki'

config = MediaWiki::Config.new ARGV 

mw = MediaWiki::Gateway.new(config.url, { :loglevel => Logger::DEBUG } )
mw.login(config.user, config.pw)
ARGF.readlines.each do |image|
  image.strip!
  unless File.exist? image
    File.open(image, 'w') do |file|
      file.write(mw.download(image))
    end
  end
end

