#########################################
###   VONAGE BUSINESS OPENVPN WRAPPER  ##
#########################################
# Python wrapper for Openvpn and our current LDAP + TOTP token solution
# So many module imports! 
# I Wish there was a cleaner way, but these are all self contained in theory.
# Meanting that py2exe should work well on this ultimately.
# -Jsmith


####################################
# Modules List
####################################
import base64
import binascii
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
import onetimepass as otp
import os
import subprocess
import time
####################################

# We're using a stupid encryption key here.  Deal with it.
# At least it creates an AES256 encryption string?
key = '0123456789abcdef0123456789abcdef'
nonce = get_random_bytes(32)
credentialsfile = 'encryptedcredentials.txt'

# Things I need to do:
# Get the GUI element to show the connection?


# If the credentials file doesn't exist, encrypt the values we get
# And stick them in the credentials ASCII armored .txt file
# I'm sure there's a better way.  If you find it, make it happen.
if (not os.path.isfile(credentialsfile)):
    print 'There is currently no credential file found in the local directory'
    print 'Please fill out the details below to create one'
    usernameinput = raw_input('     Enter your LDAP username: ')
    passwordinput = raw_input('     Enter your LDAP password: ')
    secretinput = raw_input('Enter your OAUTH Secret Token: ')
    file_out = open(credentialsfile, "w+")
    cipher = AES.new(key, AES.MODE_EAX, nonce)
    encryptedusername, usernametag = cipher.encrypt_and_digest(usernameinput)
    cipher = AES.new(key, AES.MODE_EAX, nonce)
    encryptedpassword, passwordtag = cipher.encrypt_and_digest(passwordinput)
    cipher = AES.new(key, AES.MODE_EAX, nonce)
    encryptedsecret, secrettag = cipher.encrypt_and_digest(secretinput)
    file_out.write(binascii.b2a_base64(nonce))
    file_out.write(binascii.b2a_base64(usernametag))
    file_out.write(binascii.b2a_base64(encryptedusername))
    file_out.write(binascii.b2a_base64(encryptedpassword))
    file_out.write(binascii.b2a_base64(passwordtag))
    file_out.write(binascii.b2a_base64(encryptedsecret))
    file_out.write(binascii.b2a_base64(secrettag))
    file_out.close()

# Need to add an additional TAP adapter if there aren't already two.
P1 = subprocess.Popen(['openvpn', '--show-adapters'], stdout=subprocess.PIPE)
tapcount = len(P1.stdout.readlines())
if tapcount != 3:
    print 'We do not have enough TAP adapters.'
    print 'Adding another one now using the addtap.bat file from the TAP-Windows directory'
    env = os.environ
    addtapprocess = subprocess.Popen(["C:/Program Files/TAP-Windows/bin/addtap.bat"], env=env)
	
# We now have a credentials file with ASCII encoded binary values.
# Let's get them out of there and back to decoded binary values.
# Then, let's get them back to decrypted values so we can use them.
with open(credentialsfile) as f:
    mylist = f.readlines()

#All the variables!
# For each decryption, we need a tag and an actual encrypted payload
# Without the tag you can't decrypt the data
nonce = binascii.a2b_base64(mylist[0])
usernametag = binascii.a2b_base64(mylist[1])
encryptedusername = binascii.a2b_base64(mylist[2])
encryptedpassword = binascii.a2b_base64(mylist[3])
passwordtag = binascii.a2b_base64(mylist[4])
encryptedsecret = binascii.a2b_base64(mylist[5])
secrettag = binascii.a2b_base64(mylist[6])

#Decrypt Username
cipher = AES.new(key, AES.MODE_EAX, nonce)
username = cipher.decrypt_and_verify(encryptedusername, usernametag)
#Decrypt Password
cipher = AES.new(key, AES.MODE_EAX, nonce)
password = cipher.decrypt_and_verify(encryptedpassword, passwordtag)
#Decrypt Secret
cipher = AES.new(key, AES.MODE_EAX, nonce)
secret = cipher.decrypt_and_verify(encryptedsecret, secrettag)

# Next stop, calling openvpn and pointing it to our config file
#Now we can loop over the ovpn files in the current directory
count = 0
for ovpnfile in os.listdir(os.getcwd()):
    if ovpnfile.endswith(".ovpn"):
	#Looping over all our ovpn files
	print 'Now attempting connection to '+ovpnfile
	# Generate our one time token
	token_length = 6
	my_token = otp.get_totp(secret)
	# Write the conf file
	cf = open('login.conf', 'w+')
	cf.write(username)
	cf.write('\n')
	cf.write(password+str(my_token))
	cf.close()
        #Get the login.conf file full path for openvpn
	loginconffile = os.getcwd()+'\login.conf'
	pid = subprocess.Popen(['openvpn', '--config', ovpnfile, '--auth-user-pass', loginconffile]).pid
	#gui = subprocess.Popen(['openvpn-gui', '--config_dir', os.getcwd(), '--connect', ovpnfile])
	print count
	count += 1
	time.sleep(30.5)
	os.remove(loginconffile)
	continue

#End of File
