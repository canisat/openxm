#!/usr/bin/perl
#
# sleep.cgi v1.1
#
# sleep.cgi Copyright (C) 2003, 2004 Christopher J. Carlson <c@rlson.net>
#
# sleep.cgi is part of the OpenXM Package.
# OpenXM Copyright (C) 2003, 2004 Christopher J. Carlson <c@rlson.net>
# OpenXM is a set of Perl scripts used to interface the XMPCR XM Radio
# Receiver.  
#
# The Countdown Code was originally written by
# Michael P. Scholtis (mpscho@planetx.bloomu.edu)
# Many thanks to him for his Java skills and allowing others to use it
# in their programs.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

use CGI qw(:standard escapeHTML);
use IO::Socket;
use LWP::Simple qw($ua get);

# This is strictly used to turn off the tracking when the sleep
# timer powers off the unit.

my $tracker = undef;		# Set to 1 to enable XMTracker &
				# Set TRACKER_SERVER, USERNAME & PASSWORD below.
if (defined($tracker)) {
    require XMTracker;

    my $TRACKER_SERVER = 'http://tracker.xmfan.com/';
    my $USERNAME = 'XMFAN.COM_USERNAME_HERE';
    my $PASSWORD = 'XMFAN.COM_PASSWORD_HERE';
    $tracker = XMTracker->new(server => $TRACKER_SERVER, un => $USERNAME, pw => $PASSWORD);
}

if (param('Shutdown') eq '1') {

    my $host = 'localhost';
    my $port = '3877';

    my $sock = IO::Socket::INET->new(
           PeerAddr => $host,
    	   PeerPort => $port,
    	   Proto    => 'tcp',
    	   Type     => SOCK_STREAM,
    	   Timeout  => 15);

    die "Client failed to connect" unless $sock;

    print "Content-type:text/html\n\n";
    print "<html>";
    print "<body bgcolor='black' text='white' onLoad='setTimeout(window.close, 5000)'></body>";
    print "Shutting Down OpenXM";
    
    if (defined($tracker)) {
        $tracker->update_tracker('channel_num => "OFF"');
    }
    print "</html>";    
    print $sock "xmPOW:OFF:XXX";
    close($sock);

} else {

print "Content-type:text/html\n\n";

#------------------------------------------------------------------------------
print <<HTML;
<!doctype html public "-//W3C//DTD HTML 3.2 Final//EN">
<html>
<head>
<title>OpenXM Sleep Timer</title>

<script language="JavaScript">
<!-- Begin

var cancel;
var down;
var min1,sec1;
var cmin,csec;

function Minutes(data) {
	for(var i=0;i<data.length;i++) if(data.substring(i,i+1)==":") break;
	return(data.substring(0,i)); }

function Seconds(data) {
	for(var i=0;i<data.length;i++) if(data.substring(i,i+1)==":") break;
	return(data.substring(i+1,data.length)); }

function Display(min,sec) {
	var disp;
	if(min<=9) disp=" 0";
	else disp=" ";
	disp+=min+":";

	if(sec<=9) disp+="0"+sec;
	else disp+=sec;
	return(disp); }

function Stop() {
	cancel=1;
	cmin=0; csec=1; }

function Down() {
	cancel=0;
	cmin=1*Minutes(document.timer.beg1.value);
	csec=0+Seconds(document.timer.beg1.value);
	DownRepeat(); }

function DownRepeat() {
	csec--;
	if(csec==-1) { csec=59; cmin--; }
	document.timer.disp1.value=Display(cmin,csec);
	
	if((cmin==0)&&(csec==0)) {
		if (cancel==1) {
			alert("Sleep Timer Cancelled"); }
		else 
                        window.open("sleep.cgi?Shutdown=1","","location=no,toolbar=no,menubar=no,scrollbars=no,resizable=yes,width=200,height=50"); }
	else down=setTimeout("DownRepeat()",1000); }

// End -->
</script>

</head>
<body bgcolor="black" text="white">

<center>

<form name="timer">
<table border="3" width="100%">
<tr>
   <th colspan="2" bgcolor="#336699">OpenXM Sleep Timer</th>
</tr>
<tr align="center">
   <td>Sleep in:<br><input type="text" name="beg1" size="6" value="15:00"></td>
   <td><input type="button" value="Start" onclick="Down()"><br>
       <input type="button" value="Cancel" onclick="Stop()">
   </td>
</tr>
<tr align="center">
   <td colspan="2" bgcolor="#336699">
      <input type="text" name="disp1" size="6">
   </td>
</tr>
</table>
</center>


<font size="-2">OpenXM &copy Copyright 2003, 2004 Christopher J. Carlson (c\@rlson.net)</font>

</body>
</html>
HTML

#------------------------------------------------------------------------------

}
