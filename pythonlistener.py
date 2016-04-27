#! /usr/bin/env python

# -------
# SUMMARY
# -------
# Extremely simple webhook listener for GitLab -> RT integration.
# This listener takes the gitlab JSON and
# searches for an RT formatted tag in the commit message.
# If it finds it, it emails the commit information to RT.
# RT will add that email as a comment on the ticket in question.
# It is designed to run on the gitlab server and only listen
# on localhost:<port>.
#
# -JSmith 2016.04.27

# USAGE:
# run the script (in screen, etc.) using: "python pythonlistener.py"
# In the GitLab WebUI goto your project -> settings -> webhooks
# Then in the text field, enter http://127.0.0.1:<port>
# Then click "add web hook"

## IMPORTS ##
import BaseHTTPServer # To listen for POSTs from Gitlab
import json           # To allow for json parsing
import re             # To allow for regex matching
import smtplib        # So we can email the ticket system when we have a match
import string         # Easier message body formatting


## VARIABLES ##
TCP_IP = '127.0.0.1'                     # localhost only please
TCP_PORT = 8444                          # Pick an unused port, this just happened to be the example
toaddress = 'helpdesk@yourRTserver.com'  # Modify as needed

# REGEX MATCH
# To match: [RT #1234]
# Or variants there in.
# So open [, text/numbers, space, # sign, numbers, close ]
# This is the pattern RT looks for to auto-comment a ticket with the email contents.
ticketstring = re.compile('\[[a-zA-Z0-9]+\ \#[0-9]+\]')


## WEBSERVER CLASS ##
class HTTPServer(BaseHTTPServer.BaseHTTPRequestHandler):
    def _set_headers(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()

    def do_HEAD(self):
        self._set_headers()

    def do_POST(self):
        self._set_headers()
        self.data_string = self.rfile.read(int(self.headers['Content-Length']))

        self.send_response(200)
        self.end_headers()

        json_data = json.loads(self.data_string)
        commiticareabout = json_data['after']
        for each in json_data['commits']:
          if commiticareabout == each['id']:  #Again, only want to deal with the most recent commit.
            commitmessage = each['message']
            if re.search(ticketstring,commitmessage):
              #Setting some variables that are used for email.
              fromaddress = each['author']['email']
              commitid = each['id']
              commiturl = each['url']
              commituser = each['author']['name']
              MSGBODY= string.join(( 
                "From: %s" % fromaddress,
                "To: %s" % toaddress,
                "Subject: %s" % commitmessage ,
                "",
                " Git Commit by: %s" % commituser,
                "     Commit ID: %s" % commitid,
                "    Commit URL: %s" % commiturl,
                "Commit Message: %s" % commitmessage,
                ), "\r\n")
              ## EMAIL SECTION ##
              # Slightly modified email send example from python docs
              mailserver = smtplib.SMTP('localhost')
              # sendmail function takes 3 arguments: sender's address, recipient's address
              # and message to send - here it is sent as one string.
              mailserver.sendmail(fromaddress, toaddress, MSGBODY)
              mailserver.quit()
              # And now we simple printout something if there was no match for testing.  Remove these three lines in production.
            else:
              print "Commit message doesn't match regex"
        return

# Start and run the http listener until we kill it.
# Probably need to put this in a wrapper or some kind of persistent thing on the server.
httpd = BaseHTTPServer.HTTPServer((TCP_IP, TCP_PORT), HTTPServer)
print 'Starting httpd...'
httpd.serve_forever()
