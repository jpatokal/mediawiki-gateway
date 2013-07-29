#!/usr/bin/env ruby
# Helper script for running a live FakeMediaWiki instance instead of just shamracking it.
require 'rubygems'
require 'sinatra/base'
require 'spec/fake_media_wiki/app'

FakeMediaWiki::App.run! :host => 'localhost', :port => 9090

