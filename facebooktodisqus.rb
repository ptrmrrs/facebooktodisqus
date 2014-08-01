#!/usr/bin/env ruby

#############################
# facebooktodisqus.rb
#
# Version       : 0.1
# Last Modified : 1 August 2014
#
# Author        : Pete Morris (yetanotherpete)
# Email         : pete@yetanotherpete.com
# Web           : http://yetanotherpete.com
#
#############################
#
# This command-line utility will accept any valid sitemap and download
# Facebook comments for all URLs within. It will then produce a Wordpress 
# (WXR) XML file capable of being used as input into the import utility for 
# Disqus, located at http://import.disqus.com.
#
# Please note that this will only work if your permalinks stay the same.
#
#############################
#
# Usage:
#   ./facebooktodisqus.rb SITEMAP [-o OUTPUT_FILE.XML] [-v]
#
# SITEMAP can be either a local file or a URL (just be sure to include http[s]://)
#
# e.g.
#   ./facebooktodisqus.rb local_sitemap.xml
#   ./facebooktodisqus.rb http://example.com/remote_sitemap.xml -o my_output_file.xml -v
#
# For more options:
# ./facebooktodisqus.rb -h
#
#############################

require 'optparse'
require 'ostruct'
require 'uri'
require 'nokogiri'
require 'net/http'
require 'open-uri'
require 'json'

# CONFIG
FB_URL = 'https://graph.facebook.com/comments/?ids=' # URL to access Facebook comments
COMMENT_STATUS = 'open' # default status of comments for a page. Valid options are 'open' and 'closed'
APPROVED_STATUS = 1 # default status of comments for a page. Valid options are 1 for approved or 0 for unapproved
CONTENT_HTML = '' # Future version
DATE_HTML = '' # Future version

class FacebookToDisqus

  # Parse commandline options
  def self.parse(args)
    options = OpenStruct.new
    options.verbose = false
    options.output = "facebook_comments.xml"

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: ./facebooktodisqus.rb SITEMAP [-o OUTPUT_FILE.XML] [options]"

      opts.on("-o", "--output FILENAME", String, "File to save Disqus XML. Defaults to facebook_comments.xml") do |o|
        options.output = o
      end

      opts.on("-v", "--verbose", "Enable verbose mode") do |v|
        options.verbose = v
      end

      opts.on_tail("-h", "--help", "Show this message") do 
        puts opts
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end

  # Loads sitemap XML
  def self.load_sitemap(sitemap_param)
    if sitemap_param =~ /\A#{URI::regexp}\z/ # Test if sitemap is a URL
      begin
        xml = Nokogiri::XML(open(sitemap_param))
      rescue
        puts "ERROR: Couldn't open sitemap from URL."
        exit
      end
    else # if it's not a URL, assume it's a file
      begin
        f = File.open(sitemap_param)
        xml = Nokogiri::XML(f)
        f.close
      rescue
        puts "ERROR: Couldn't open sitemap from file"
        exit
      end
    end

    if (xml.errors.empty?)
      puts "Successfully parsed #{sitemap_param}"
      xml.remove_namespaces!
      xml
    else 
      puts "ERROR: Not a valid XML file"
      puts xml.errors
      exit
    end
  end

  # Pulls page attributes from URLs stored in sitemap
  def self.get_site(xml)
    page_hash = Hash.new

    xml.xpath('//url').each do |u| # for each url in the sitemap

      url = u.xpath('loc').text # get the site's url

      fb_comments = get_facebook_comments(url)

      puts "Retrieved #{fb_comments.count} comments for #{url}" if $verbose

      unless fb_comments.empty?
        page = Nokogiri::HTML(open(url))
        page_content = CONTENT_HTML.empty? ? '' : page.css(CONTENT_HTML)
        date = DATE_HTML.empty? ? u.xpath('lastmod').text : page.css(DATE_HTML) # set lastmod as the post's date. not accurate, but the best we can get from XML

        details = {
          :title => page.css('title')[0].text,
          :slug => url.match(/([^\/.]*)\/$/).to_s.chop,
          :date => date,
          :content => page_content,
          :comments => fb_comments
        }

        page_hash[url] = details
      end

    end
    puts "#{page_hash.size} URLS retrieved" if $verbose
    page_hash
  end

  # Downloads JSON of Facebook comments for a URL then reformats it into a nicer array of hashes
  def self.get_facebook_comments(url)
    facebook_json = JSON.load(open(URI.parse(FB_URL + url)))
    page_comments = Array.new

    facebook_json.each do |raw_url, raw_comments|
      unless raw_comments['comments']['data'].empty?

        raw_comments['comments']['data'].each do |c|
          comment = Hash.new
          comment[:id] = c['id']
          comment[:author] = c['from']['name']
          comment[:date] = c['created_time'].sub(/[T]/, ' ').sub('+0000','')
          comment[:content] = c['message']

          page_comments << comment
        end
      end
    end
    page_comments
  end

  # Builds XML file from hash of entire site with comments
  def self.save_xml(site)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.rss('version'=>'2.0', 'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/', 'xmlns:dsq' => 'http://www.disqus.com/', 'xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 'xmlns:wp' => 'http://wordpress.org/export/1.0/') {
        xml.channel {
          site.each do |url, page|
            xml.item {
              xml.title page[:title]
              xml.link url
              xml['content'].encoded { 
                xml.cdata page[:content]
              }
              xml['dsq'].thread_identifier page[:slug]
              xml['wp'].post_date_gmt page[:date]
              xml['wp'].comment_status COMMENT_STATUS
              
              page[:comments].each do |c|
                xml['wp'].comment_ {
                  xml['wp'].comment_id c[:id]
                  xml['wp'].comment_author c[:author]
                  xml['wp'].comment_author_email
                  xml['wp'].comment_author_url
                  xml['wp'].comment_author_IP
                  xml['wp'].comment_date_gmt c[:date]
                  xml['wp'].comment_content {
                    xml.cdata c[:content]
                  }
                  xml['wp'].comment_approved APPROVED_STATUS
                  xml['wp'].comment_parent
                }
              end
            }
          end
        }
      }
    end

    begin
      File.open($output,'w'){ |f| f.write builder.to_xml } 
    rescue
      puts "ERROR: Couldn't write XML file."
      exit
    else
      puts "Successfully wrote #{$output} with comments for #{site.size} pages."
    end

  end
end

options = FacebookToDisqus.parse(ARGV)

if ARGV.empty? 
  FacebookToDisqus.parse(["-h"])
  exit
end

$verbose = options[:verbose]
$output = options[:output]

xml = FacebookToDisqus.load_sitemap(ARGV[0])
site = FacebookToDisqus.get_site(xml)

unless site.empty?
  FacebookToDisqus.save_xml(site)
else
  puts "No URLs found in #{ARGV[0]}."
end
