# Facebook To Disqus Comment Converter
This is a command-line utility that will accept any valid sitemap and download Facebook comments for all URLs in the sitemap. It will then produce a Wordpress  (WXR) XML file capable of being used as input into the import utility for Disqus, located at http://import.disqus.com.

Please note that this will only work if your permalinks stay the same.

## Installation and Setup
### Er, do I need anything first?
Yep. You need to install this:

 - **nokogiri** 1.6.3.1

It's available as a gem, so try the following:

```
gem install nokogiri
```

### Installing
Pretty easy! Download `facebooktodisqus.rb` and put it somewhere meaningful.

Make it executable with the following terminal command:

```
chmod u+x facebooktodisqus.rb
```

That's it!

## So how do I use it?
Well, it's a command line utility.... so you run it from the command line. You need to specify a valid sitemap file, but you can do it with either a local file or a URL (make sure you include http/https://). This is what it looks like with a local file:

```
./facebooktodisqus.rb sitemap.xml
```

And here is what it looks like with a remote sitemap:

```
./facebooktodisqus.rb http://www.example.com/sitemap.xml
```

You can run it in verbose mode with the `-v` flag like so:

```
./facebooktodisqus.rb -v sitemap.xml
```

And you can specify your own output file with `-o`

```
./facebooktodisqus.rb sitemap.xml -o fb.xml
```

By default, the script will write to facebook_comments.xml

## Anything else?
I... don't think so.
