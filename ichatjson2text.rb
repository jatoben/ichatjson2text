#!/usr/bin/env ruby
# Converts JSON iChat message input to plain text for archival purposes.
require "date"
require "json"
require "stringio"

# Message archives have the time in fairly standard format
# (`2008-04-22T21:11:08.000`) but without a timezone. The messages
# I'm converting were all created in US Central, so a crude check
# is used to see if CST (-06:00) or CDT (-05:00) should be used.
def format_datetime(str)
  return unless str

  # DST starts in November and ends in March. Close enough for rock'nroll.
  mm = str[5..6].to_i
  offset = (mm >= 11 || mm <= 3) ? "-05:00" : "-06:00"

  DateTime.parse(str + offset).to_s
end

# Some iChat message bodies include HTML; nuke that.
def strip_html(str)
  return unless str
  str.gsub(/<\/?[^>]*>/, "")
end

# ichat2json doesn't exactly produce valid JSON input; each dict
# is not separated with a comma, so it's not a JSON array, and
# quotes in HTML are not escaped (e.g. `<font face=\"Helvetica\">`).
#
# The quickest way to fix this up is to make `jq` deal with it.
def json_fixup(input)
  fixed_output = IO.popen("jq -c .", "r+") do |i|
    i.puts(input)
    i.close_write
    i.read
  end
end

# Converts a JSON message to plain text output.
# This goes line-by-line so that in case some parsing fails, it still
# gets as much of the input as possible.
def convert(input)
  begin
    msg = JSON.parse(input, symbolize_names: true)
    return nil unless msg.length > 0

    "<#{msg[:sender]}> [#{format_datetime(msg[:date])}] #{strip_html(msg[:message])}"
  rescue => e
    "*** message conversion failed: #{e} ***"
  end
end

input = StringIO.new(json_fixup(ARGF.read))
input.readlines.each { |line| message = convert(line); puts message if message }
