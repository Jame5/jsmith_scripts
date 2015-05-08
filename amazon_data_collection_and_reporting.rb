#!/usr/local/rvm/rubies/ruby-2.1.3/bin/ruby
#####
# Script to parse out and email events from AWS-CLI
#####
require 'rubygems'
require 'json'
require 'aws-sdk'
require 'net/smtp'


$sites = YAML::load(File.open('path-to-yaml-file-with-creds-in-it'))

west = 'us-west-2'
east = 'us-east-1'

# Because we have to pass umpteen nested hashes to get the instance status
options_hash = {
:filters => [{
  :name => 'event.code',
  :values => ['*']
}] 
}

# Final data array
hash_to_manipulate={}

#Initializing a global string for the consolidated email message
msg = ""

# Mail addresses to receive the consolidated email message.
# It seemed easiest to define it here
tomailaddr=['array_ofmail_addresses','what_he_said']

# Collection of events function
def find_events(site,location,options_hash,hash_to_manipulate)
  creds = $sites[site]
     id = creds['id']
    key = creds['key']

  connection = AWS::EC2.new(
    :access_key_id => id,
    :secret_access_key => key,
    :region => location
  )
  AWS.memoize do
    # Trying to get the responses for just systems that have Events that are not null
    # In theory the "anything with an event.code" wildcard value above seems to work.
    instance_details = connection.instances.filter('instance-state-name', 'running')
    response = connection.client.describe_instance_status(options_hash)
    response[:instance_status_set].each do |instances_with_events|
      my_instance = instances_with_events[:instance_id]
      my_events = instances_with_events[:events_set].first
      my_name = instance_details[my_instance].tags['Name']
      hash_to_manipulate[my_instance.to_sym] = { :name => my_name, :code => my_events[:code], :description => my_events[:description], :not_before=> my_events[:not_before], :region => location, :site => site }
    end
  end
end

## Email function created here using net/smtp
## Ripped wholesale from deploy_puppet.rb

def send_mail(msg,tomailaddr)
  fromaddr = '<frommailaddress>'
  Net::SMTP.start('localhost', 25, '<fromdomain>') do |smtp|
    emailmessage = <<END
From: <From Mail address>
To: #{tomailaddr.join('; ')}
MIME-Version: 1.0
Content-type: text/html
Subject: Instance Report
#{msg}
END
    smtp.send_message emailmessage, fromaddr, tomailaddr
  end
end

# The workhorse of the script
# Takes our hash and manipulates it into an HTML doc
def email_creation(hash_to_manipulate,msg)
  retirement_site=[]
  others_site=[]
    sorted_hash =  hash_to_manipulate.sort_by{ |instance, details| details[:not_before] }
    sorted_hash.each do |instance, details|
      if details[:code] == "instance-retirement"
        retirement_site << "<tr><td>#{details[:name]}</td><td>#{instance}</td><td>#{details[:code]}</td><td>#{details[:not_before]}</td><td>#{details[:region]}</td><td>#{details[:site]}</td></tr>"
      else
        unless details[:description] =~ /\[Completed\]|\[Canceled\]/
          others_site << "<tr><td>#{details[:name]}</td><td>#{instance}</td><td>#{details[:code]}</td><td>#{details[:not_before]}</td><td>#{details[:region]}</td><td>#{details[:site]}</td></tr>"
        end
      end
    end
    # This is so people know the system is working, but that nothing happened today
    if retirement_site.empty? and others_site.empty?
      msg << "<html>"
      msg << "<body>"
      msg << "<h3>No events today!  Have a nice day! :)</h3>"
      msg << "</body>"
      msg << "</html>"
    end
    unless retirement_site.empty? and others_site.empty?     
      msg << "<html>"
      msg << "<body>"
      unless retirement_site.empty?
        msg << "<h3>Instances that are being terminated!</h3>"
        msg << "<table border=\"1\" cellpadding=\"5\">"
        msg << "<tr><th>Instance Name</th><th>Instance ID</th><th>Event</th><th>Earliest Date of Event</th><th>Region</th><th>Site</th></tr>"
        msg << "#{retirement_site.join("\n")}"
        msg << "</table>"
        msg << "<p><p>"
      end
      unless others_site.empty?
        msg << "<h3>Instances with non-terminal events.</h3>"
        msg << "<table border=\"1\" cellpadding=\"5\">"
        msg << "<tr><th>Instance Name</th><th>Instance ID</th><th>Event</th><th>Earliest Date of Event</th><th>Region</th><th>Site</th></tr>"
        msg << "#{others_site.join("\n")}"
        msg << "</table>"
      end
      msg << "</body>"
      msg << "</html>"
    end
end

##################
# Functional Bit #
##################

region_array = [east,west]
# Below, credentials not used, but I needed to define something.
# Might as well define what is actually there.
$sites.each do |site,credentials|
  region_array.each do |some_location|
    find_events(site,some_location,options_hash,hash_to_manipulate)
  end
end

#This section is easier since it's one email that is created and sent for ALL sites.
email_creation(hash_to_manipulate,msg)
send_mail(msg,tomailaddr)
