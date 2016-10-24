CIPIT - Cisco IP Phone Inventory Tool
--------------------------------------------
Version 0.09
Author:  Vince Loschiavo

This product is made available subject to the terms of GNU Lesser General Public License Version 2.1.

Last updated: 2013-04-15
Moved from sourceforge, original project here: https://sourceforge.net/projects/cipinventory/

--------------------------------------------
MD5SUM:
fb69d7808b87db719706373ffeee7ed0  cipit.pl

--------------------------------------------
REQUIREMENTS:

-At least one Cisco IP Phone with the web page enabled
-A *nix or Windows machine with a Perl interpreter installed.  http://www.activestate.com/Products/activeperl/ is one such example.
-A list of IP addresses of your phones.  
	This can be obtained in a variety of ways....the simplest is a copy and paste from CCMADMIN
	Alternatively: "show ephone | redirect tftp://yourtftpserverip/inputfilename.txt"
-Network Connectivity to your phones.  


--------------------------------------------
USAGE:

CIPIT requires two command line arguments.
	
	
	cipit.pl <input file> <output.cvs file>
	
	
The input file should be a text file with one IP per line.
One way to create this input file is to cut and paste the Device Page
of your Cisco CCM into a spreadsheet and remove the CCM server IPs.


CIPIT will only grab one IP per line and ignore the rest.


Alternatively if you are using CCME the following command works well:
show ephone | redirect tftp://<yourTftpServerIP>/inputfilename.txt


Thank you for using CIPIT.  Version Number: $versionnumber

Feel free to examine the code and offer suggestions to the author.
<first initial> + <last name> @ gmail d0t com
Vince Loschiavo

---------------------------------------------
Planned Features for future release v0.10:

	Plans to support CIDR IP notation from the commandline

---------------------------------------------
Current Features:
v0.09
	Added Support for 7906.  Thank you to the anonymous poster on sourceforge.

v0.08
This script was tested with Cisco SCCP images:
7905, 7910, 7911, 7912, 7920, 7940, 7941, 7960, 7961, 7970.

It doesn't work for Cisco 7935 or 7936 phones 
as you have to log into the phones web page....

	-Includes Duplicate IP checking
	-Limited reporting on Phones that do not respond
	-Overwrite file check
	-progress indicator

