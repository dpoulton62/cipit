#!/usr/bin/perl
######################################################
# Cisco IP Phone Inventory Tool
# (CIPIT)
# This Script was written by Vince Loschiavo 
# Mar-21-2008
#
# if you enjoy it, please drop me an email: 
# <first initial> + <last name> @ gmail d0t com
# 
# Or follow the project on sourceforge
# https://sourceforge.net/projects/cipinventory/
#
# This script was tested with Cisco SCCP images:
# 7905, 7906, 7910, 7911, 7912, 7920, 7940, 7941, 7960, 7961, 7970.
#
# It doesn't work for Cisco 7935 or 7936 phones 
# as you have to log into the phones web page....
#
#	-Includes Duplicate IP checking
#	-Reporting on Phones not responding
#	-Overwrite file check
#	-progress indicator
#	-Added Support for 7905s & 7912s
#
# Features to add:
#	Grab Registered IP's from CCM or CCME
######################################################

use LWP::Simple;
use Time::HiRes qw( sleep );
use strict;
use warnings;

# my @sparkle = qw( \ | / - );	# Other Progress indicator characters;
# my @sparkle = qw( ^ > v < );  # Other Progress indicator characters;
# my @sparkle = ("(", "]", ")", "|", "(", "|", ")", ")");  # Other Progress indicator characters;
my @sparkle = qw( . o O o );  # This is the progress indicator characters;

my $cur_sparkle = 0;		# Progress indecator counter
my $url;			# This is the url of the phone's web page
my $PhoneRecordNumber = 0;	# This will be used as a unique record number
my @PhoneIPs = ();		# This is the array where the IPs will be read into from the commandline file
my $PhoneIPs;			# This is the number of valid IP addresses found in file
my $inputfile = $ARGV[0];	# This is the input filename
my $outputfile = $ARGV[1];	# This is the output filename 
my $content;			# This contains the phone web page
my %IPs = ();			# This is a hash to store unique IP addresses
my $CurrentHost;
my $versionnumber = ("0.09");	# This script's version number
$| = 1;				# Autoflush-This is to avoid buffering output to STDOUT or FILEHANDLES

# Check to see if there's an input file specified and an output filename specified.
if ($#ARGV != 1) {

	print qq {\nCIPIT requires two command line arguments.
	
	
	cipit.pl <input file> <output.cvs file>
	
	
The input file should be a text file with one IP per line.
One way to create this input file is to cut and paste the Device Page
of your Cisco CCM into a spreadsheet and remove the CCM server IPs.

CIPIT will only grab one IP per line and ignore the rest.

Alternatively if you are using CCME the following command works well:
show ephone | redirect tftp://<yourTftpServerIP>/inputfilename.txt

Thank you for using CIPIT.  Version Number: $versionnumber
Feel free to examine the code and offer suggestions to the author.
};

	exit;
	
 } # End usage if check

# Check to see if there's a .CVS extension on the end of the outputfile name
if ($outputfile !~ /\.[Cc][Ss][Vv]$/) {
	$outputfile = ($outputfile . ".csv");	# Add .csv extenstion if it's missing.
 }

if (-e $outputfile) {
	print ("\n\nWarning!\n\nThe file: $outputfile already exists.\nWould you like to attempt to replace? ");
	if (<STDIN> !~ /^[Yy]/) {
		exit;
	 }
}

open (INPUTFILE, $inputfile) || die "Couldn't open $inputfile for reading:  $!\n";

# First we will read each line of the file and look for a valid IP address, then add it to a hash as the Key, and increment the value.
# This step is necessary to remove any duplicate IPs.
while (<INPUTFILE>) {
        chomp;
        if ($_ =~ /\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/) { 		# Verify that it's a valid IP address
	$CurrentHost = ("$1.$2.$3.$4");
        $IPs{$CurrentHost}++;					# Add item to Hash and increment value once
        }
}

close INPUTFILE || die "Couldn't close $inputfile for some unknown reason: $!\n";

# Let's do some sanity checking to verify the input file actually contains data.
if (keys(%IPs) > 0) 		
 {
 	# Print that number before we begin gathering data.
	print "\nI read $inputfile sucessfully.\nThere are " . keys(%IPs) . " Valid IP Addresses.\n\n";	
	@PhoneIPs = keys(%IPs);					#This puts the IPs into an array for ease of handling.
 } else { 
	print "\n\nI was expecting a commandline argument that includes one IP address per line.\n";
	exit;
 }

# Let's see if the user would like to continue.
print "Would you like to continue? ";
if (<STDIN> =~ /^[Yy]/) {

	# Open a file for writing
	open (CVSOUTPUT, "> $outputfile") or die "Couldn't open $outputfile for writing: $!\n";

	# Write File Headers
	print CVSOUTPUT ("Phone Record Number,IP Address,Model Number,MAC Address,Host Name,Phone DN,Phone Load Version,Phone Serial Number\n");
	print("Working: ");
	print(' ');
	# For each IP get it's index.html
BIG:	foreach (@PhoneIPs) {
		$cur_sparkle = ($cur_sparkle + 1) % @sparkle;
		print("\010$sparkle[$cur_sparkle]");
		$url = "http://$_";	
		$PhoneRecordNumber++;		# Increment the Record Number Counter

		# Let's grab the URL and put in a variable called content
		$content = get $url;
		
		# Check if $content is defined;
		if (not defined($content)) {
			print CVSOUTPUT "$PhoneRecordNumber,";				# Print the Record Number
			print CVSOUTPUT "$_,";						# Print the IP Address of the Phone
			print CVSOUTPUT "Not Responding\n";
			next BIG unless defined($content);
		 }
		
		# Let's look for the information we need.

		print CVSOUTPUT "$PhoneRecordNumber,";	# Print the Record Number
		print CVSOUTPUT "$_,";			# Print the IP Address of the Phone

		#Check model numbers:
		if($content =~ /ATA 18/) {		#if it's an ATA186 or ATA188 then call the 18x subroutine
			&ata18x($content, $url);
		 } elsif ($content =~ /CP-7920/) {	# if it's a 7920...call that sub
		 	&cp7920($content, $url);
		 } elsif ($content =~ /dynaform\/index_Dyna.htm/) {	# if it's a 793x...call that sub
		 	&cp793x($content, $url);
		 } elsif (($content =~ /CP-7911/) || ($content =~ /CP-7906G/)) {	# If it's a 7911 or 7906,  call that sub
		 	&cp7911($content, $url);
		 } elsif (($content =~ /CP-7905G/) || ($content =~ /CP-7912G/)) {	# If it's a 7905 or a 7912, call that sub
		 	&cp79057912($content, $url);
		 } else {				# if it's none of the above, then do your best.
		 
			# Most other phones:  Tested on 7910, 7941, 7960, 7961, 7970. 
			if($content =~ /Model Number<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([\+\/0-9A-Za-z-]+)<\/B><\/TD>/) 
			 {
				print CVSOUTPUT ("$1,");
				} else {
				print CVSOUTPUT ("N/A,");
			 }

			# Find the MAC Address
			if($content =~ /MAC Address<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z-]+)<\/B><\/TD>/)
			 {
			        print CVSOUTPUT ("$1,");
			        } else {
	        		print CVSOUTPUT ("N/A,");
		 	}

			# Find the Host Name
			if($content =~ /Host Name<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z]+)<\/B><\/TD>/)
			 {
			        print CVSOUTPUT ("$1,");
			        } else {
			        print CVSOUTPUT ("N/A,");
			 }

			# Find the Phone's DN
			if($content =~ /Phone DN<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z-]+)<\/B><\/TD>/)
			 {
			        print CVSOUTPUT ("$1,");
			        } else {
	        		print CVSOUTPUT ("N/A,");
			 }

			# Find the Phone Load Version number
			if($content =~ /Version<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([\.\(\)0-9A-Za-z-]+)<\/B><\/TD>/)
			 {
		        	print CVSOUTPUT ("$1,");
			        } else {
		        	print CVSOUTPUT ("N/A,");
			 }

			# Find the Phone Serial Number
			if($content =~ /Serial Number<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z]+)<\/B><\/TD>/)
			 {
			        print CVSOUTPUT ("$1");
			        } else {
			        print CVSOUTPUT ("N/A");
			 }
			# Print a newline to start a new record
			print CVSOUTPUT ("\n");
		 }	# end elseifs
		}	# foreach loop end
	
	close (CVSOUTPUT) || die "Can't close PhoneData.csv: $!";	# Close File

 }	# End of If Y/N Loop 

print("\010done.\n");   # or: print("\010 \010");			# Print 'done' on progress bar.

sub ata18x
{
	# Check for Special Case: ATA186 and ATA188
 	$url = ($url . "/DeviceInfo");		# Change URL to get correct URL for this device
	$content = get $url;			# Get new URL

	# Get Product ID from Device
	if($content =~ /Product ID<\/td><td>([A-Za-z0-9]+)<\/td>/)	
	 {
	 	print CVSOUTPUT ("$1,");
	 } else {
	 	print CVSOUTPUT ("N/A,");
	 }
	 
	# Get MAC Address from Device
        if($content =~ /MAC Address<\/td><td>([A-Za-z0-9]+)<\/td>/)
         {
                print CVSOUTPUT ("$1,");
         } else {
                print CVSOUTPUT ("N/A,");
         }

	# Get Host Name from Device
        if($content =~ /Host Name<\/td><td>([A-Za-z0-9]+)<\/td>/)
         {
                print CVSOUTPUT ("$1,");
         } else {
                print CVSOUTPUT ("N/A,");
         }

	# Get Phone DN Port1 from Device
        if($content =~ /Phone 1 DN<\/td><td>([A-Da-d0-9]+)<\/td>/)
         {
                print CVSOUTPUT ("$1 ");
         } else {
                print CVSOUTPUT ("N/A ");
         }

	# Get Phone DN Port2 from Device
        if($content =~ /Phone 2 DN<\/td><td>([A-Da-d0-9]+)<\/td>/)
        {
                print CVSOUTPUT ("$1,");
         } else {
                print CVSOUTPUT ("N/A,");
         }

        # Get Firmware Load Version from Device
	if($content =~ /App Load ID<\/td><td>([A-Za-z0-9]+)<\/td>/)
         {
                print CVSOUTPUT ("$1,");
         } else {
                print CVSOUTPUT ("N/A,");
         }

	# Get Serial Number from Device
        if($content =~ /Serial Number<\/td><td>([A-Za-z0-9]+)<\/td>/)
         {
                print CVSOUTPUT ("$1");
         } else {
                print CVSOUTPUT ("N/A");
         }

	#Print a newline to start a new record
        print CVSOUTPUT ("\n");
} # End Sub ata18x

sub cp7920
{
	# Check for Special Case: 7920 Wireless phone
	print CVSOUTPUT ("CP-7920,");	#Print Model Number
	
	# Find the MAC Address
	if($content =~ /<p><b>([A-Za-z0-9]+)<\/b><\/p><\/td><\/tr><tr style='irow:1'>/)
	 {
		print CVSOUTPUT ("$1,");
		} else {
	       	print CVSOUTPUT ("N/A,");
	}
	
	# Find the Host Name
	if($content =~ /<p><b>([A-Za-z0-9]+)<\/b><\/p><\/td><\/tr><tr style='irow:2'>/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
	        print CVSOUTPUT ("N/A,");
	 }
	# Find the Phone's DN
	if($content =~ /<p><b>([A-Za-z0-9]+)<\/b><\/p><\/td><\/tr><tr style='irow:3'>/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
		print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone Load Version number
	if($content =~ /<p><b>([A-Za-z0-9\.-]+)<\/b><\/p><\/td><\/tr><tr style='irow:4'>/)
	 {
        	print CVSOUTPUT ("$1,");
	        } else {
        	print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone Serial Number
	if($content =~ /><b>([A-Za-z0-9]+)<\/b><\/p><\/td><\/tr><tr style='irow:9'>/)
	 {
	        print CVSOUTPUT ("$1");
	        } else {
	        print CVSOUTPUT ("N/A");
	 }
	#Print a newline to start a new record
	print CVSOUTPUT ("\n");
}

sub cp793x
{
	# Check for Special Case: 7935 Conference Phone
	$url = ($url . "/dynaform/index_Dyna.htm");		# Change URL to get correct URL for this device
	$content = get $url;					# Get new URL
	if ($content =~ /(79[0-9][0-9]) Cisco IP/) {
		print CVSOUTPUT ("CP-" . $1 . ",");
	 } else {
	 	print CVSOUTPUT ("N/A,");
	 }
	print CVSOUTPUT ("N/A,");	#Print MAC Address
	print CVSOUTPUT ("N/A,");	#Print Host Name
	print CVSOUTPUT ("N/A,");	#Print Phone DN
	print CVSOUTPUT ("N/A,");	#Print Phone Load Version
	print CVSOUTPUT ("N/A,");	#Print Phone Serial Number
	print CVSOUTPUT ("\n");		#Print a newline to start a new record
}

sub cp7911
{
	if($content =~ /Model Number<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([\+\/0-9A-Za-z-]+)<\/B><\/TD>/) 
	 {
		print CVSOUTPUT ("$1,");
		} else {
		print CVSOUTPUT ("N/A,");
	 }

	# Find the MAC Address
	if($content =~ /MAC Address<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z-]+)<\/B><\/TD>/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
       		print CVSOUTPUT ("N/A,");
 	}

	# Find the Host Name
	if($content =~ /Host Name<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z]+)<\/B><\/TD>/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
	        print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone's DN
	if($content =~ /Phone DN<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z-]+)<\/B><\/TD>/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
       		print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone Load Version number
	if($content =~ /App Load ID<\/B><\/TD><td width=20><\/TD><TD><B>([A-Za-z0-9\.-]+)<\/B><\/TD>/)
	 {
        	print CVSOUTPUT ("$1,");
	        } else {
        	print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone Serial Number
	if($content =~ /Serial Number<\/B><\/TD>\W?<td width=20><\/TD>\W?<TD><B>([0-9A-Za-z]+)<\/B><\/TD>/)
	 {
	        print CVSOUTPUT ("$1");
	        } else {
	        print CVSOUTPUT ("N/A");
	 }
	# Print a newline to start a new record
	print CVSOUTPUT ("\n");	
}

sub cp79057912
{
	if($content =~ /Product ID<\/td><td>([\+\/0-9A-Za-z-]+)/) 
	 {
		print CVSOUTPUT ("$1,");
		} else {
		print CVSOUTPUT ("N/A,");
	 }

	# Find the MAC Address
	if($content =~ /MAC Address<\/td><td>([A-Fa-f0-9]+)/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
       		print CVSOUTPUT ("N/A,");
 	}

	# Find the Host Name
	if($content =~ /Host Name<\/td><td>([A-Za-z0-9]+)/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
	        print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone's DN
	if($content =~ /Phone DN<\/td><td>([A-Da-d0-9]+)/)
	 {
	        print CVSOUTPUT ("$1,");
	        } else {
       		print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone Load Version number
	if($content =~ /Software Version<\/td><td>([\(\)A-Za-z0-9\.-]+)/)
	 {
        	print CVSOUTPUT ("$1,");
	        } else {
        	print CVSOUTPUT ("N/A,");
	 }

	# Find the Phone Serial Number
	if($content =~ /Serial Number<\/td><td>([0-9A-Za-z]+)/)
	 {
	        print CVSOUTPUT ("$1");
	        } else {
	        print CVSOUTPUT ("N/A");
	 }
	# Print a newline to start a new record
	print CVSOUTPUT ("\n");	
}
