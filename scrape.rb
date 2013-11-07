require 'nokogiri'
require 'open-uri'
require 'pry'

@@doc = nil
def get_doc url
  cookie = ENV['AAPL_COOKIE']
  begin
    doc = Nokogiri::HTML(open url, 'Cookie' => cookie)
  rescue Exception => e
    puts e
  end
end

def assert_logged_in doc
  unless doc.to_s =~ /Reid Calhoon/
    puts doc.to_s
    dbg "Error: not logged in!"
    raise "Not logged in"
  end
end


# returns: doc, a nokogiri doc
def get_search_results_page i
  url = "https://aapl.ps.membersuite.com/custom/SearchDirectory_Results.aspx?page=#{i}"
  dbg "  Requesting url: #{url}"
  doc = get_doc url
  @@doc = doc
  assert_logged_in doc
  doc
end

def scrape_page i
  dbg "  Scraping page #{i}"
  doc = get_search_results_page i
  tags  = get_result_tag doc
  tag_low = (i - 1)*25 +  1
  tag_high = 25 * i
  unless tags[0] == tag_low && tags[1] == tag_high
    dbg "! unexpected tag! Got #{tags}. Was expecting #{tag_low} to #{tag_high}"
    raise "UnexpecedTags"
  end
  dbg "    results tag: #{}"

  filename = "out/#{i}.html"

  dbg "    opening #{filename} for writing"
  f = open(filename, 'w')
  result = f.write doc.to_s
  f.close
  dbg "    closing #{filename} after writing #{result}"
end

def get_result_tag doc
  s = doc.css('#siteContentWrapper div p b').to_s
  match = s.match /[\d,]+\s*through\s*[\d,]+/
  # raise unless match
  match[0].to_s.split.values_at(0, 2).map{|s| s.gsub(',','').to_i}
end

def dbg s
  puts "#{Time.now}  #{s}"
end

def scrape
  begin
    start = get_highest_existing_file_number
    (start..800).each do |i|
      dbg "Iteration #{i}"
      scrape_page i
      random_sleep
    end
  rescue Excpetion => e
    dbg "!!! Exception occured --------------------------------------------------------------------------------------------------"
    dbg "Dumping doc:"
    dbg @@doc.to_s
    exit
  end
end

def random_sleep
  dur = 2 + Random.rand(0.0..1.3)*Random.rand(1.2..7.1) - Random.rand(0.1..0.28)
  dur /= 3
  dbg "sleeping for #{dur}"
  sleep dur
end

def get_highest_existing_file_number
  Dir.glob("out/*").select{|s| s =~ /out\/\d*\.html/}.map{|s| m = s.match /\d+/; m[0].to_i}.sort.last
end

@structs = []
@rest = []

def extract_contact_structs_from_doc doc
  doc.css("#PageContent_dlMembers tr td").each do |frag|
    s = frag.inner_html
    parse_line s
  end
end

ContactInfo = Struct.new(:name, :email, :gender, :address_string, :phone_pref, :phone_mobile, :phone_work, :phone_fax, :title, :company, :work_address)

def parse_line line
  *basic, line = line.split "<br>", 4
  name, email, gender = basic.map &:strip

  address, phone, rest = line.partition("<b>Preferred Phone Number:")
  address = address.split("<br>").map(&:strip).reject(&:empty?).join("; ").strip
  line = phone + rest

  phones, blank, line = line.partition "<br><br>"
  phones = phones.split("<br>").map{|s| s.partition("</b>").last}

  job, blank, line = line.partition("<br><br>")
  title, company = job.split("<br>").map &:strip

  work_address = line.split("<br>").map(&:strip).map{|s|s.gsub "<hr>", ''}.reject(&:empty?).join("; ").strip


  c = ContactInfo.new(name, email, gender, address, *phones, title, company, work_address)
  @structs << c
  @rest << line
end

def parse
  (1..800).each do |i|
    dbg "Parse Iteration #{i}"
    extract_contact_structs_from_doc Nokogiri::HTML(open "out/#{i}.html", "r")
  end
end

def struct_to_s struct
  struct.to_a.map{|field| '"'+field.to_s+'"'}.join ","
end

def output
  f = open("data.csv", "w")
  f.puts ContactInfo.members.map(&:capitalize).map{|s| s.to_s.gsub "_", " "}.join ", "
  @structs.each do |contact|
    f.puts struct_to_s contact
  end
end

def main
  scrape
  parse
  output
end
main()
