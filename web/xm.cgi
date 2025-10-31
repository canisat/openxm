#!/usr/bin/perl
#
# xm.cgi v1.2  - Web Client used to control an XM PCR Radio
#                interfacing the XMDaemon.
#
# xm.cgi Copyright (C) 2003, 2004 Christopher J. Carlson <c@rlson.net>
#
# xm.cgi is part of the OpenXM Package.
# OpenXM Copyright (C) 2003, 2004 Christopher J. Carlson <c@rlson.net>
# OpenXM is a set of Perl scripts used to interface the XMPCR XM Radio
# Receiver.  
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

use strict;
use IO::Socket::INET;
use CGI qw(:standard escapeHTML);

my $tracker = undef;		# Set to 1 to enable XMTracker &
				# Set TRACKER_SERVER, USERNAME & PASSWORD below.
if (defined($tracker)) {
    require XMTracker;

    my $TRACKER_SERVER = 'http://tracker.xmfan.com/';
    my $USERNAME = 'XMFAN.COM_USERNAME_HERE';
    my $PASSWORD = 'XMFAN.COM_PASSWORD_HERE';
    $tracker = XMTracker->new(server => $TRACKER_SERVER, un => $USERNAME, pw => $PASSWORD);
}

my @favorites = (47, 48, 44, 46, 41, 40, 8, 53, 54);

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

if (param('Go') eq '1') {
    if (param('Change_Channel')) {
        my $new_chan = param('Change_Channel');
	print $sock "xmCHA:NEW:".$new_chan;
	close($sock);	
	print qq(<META HTTP-EQUIV=Refresh CONTENT="0; URL=http://$host/cgi-bin/xm.cgi">);
    }
    elsif (param('ChanUp')) {
    	print $sock "xmCHA:UP0:XXX";
    	close($sock);
    	print qq(<META HTTP-EQUIV=Refresh CONTENT="0; URL=http://$host/cgi-bin/xm.cgi">);
    }
    elsif (param('ChanDown')) {
    	print $sock "xmCHA:DOW:XXX";
    	close($sock);
    	print qq(<META HTTP-EQUIV=Refresh CONTENT="0; URL=http://$host/cgi-bin/xm.cgi">);
    }
    elsif (param('Mute')) {
	my $parm = uc(param('Mute'));
	print $sock "xmMUT:$parm:XXX";
	close($sock);
	print qq(<META HTTP-EQUIV=Refresh CONTENT="0; URL=http://$host/cgi-bin/xm.cgi">);
    }
	
    elsif (param('Power')) {
	my $parm = uc(param('Power'));
	print $sock "xmPOW:$parm:XXX";
	close($sock);
	if ($parm =~ /ON/i) {
            print qq(<META HTTP-EQUIV=Refresh CONTENT="10; URL=http://$host/cgi-bin/xm.cgi">);
	} else {
	    if (defined($tracker)) {
		$tracker->update_tracker('channel_num => "OFF"');
	    }
	    print qq(<META HTTP-EQUIV=Refresh CONTENT="0; URL=http://$host/cgi-bin/xm.cgi">);
	}
    }
}	

print $sock "xmPCR:DAT:XXX\n";

my $res = <$sock>;

my ($status, $command, $state, $mute, $nfo) = split /\|/,$res,5;
my ($channel_num, $station_name, $channel_group, $artist, $song) 
   = split(/~/,$nfo,5);

$artist =~ s/ +/ /g; $artist =~ s/\s$//;
$song =~ s/ +/ /g; $song =~ s/\s+$//;

if (defined($tracker)) {
    $tracker->update_tracker(channel_num => $channel_num,
    			     artist => $artist,
    			     song => $song);
}

my $title = '';
if ($artist) { $title .= "($artist)"; }
if ($song) { $title .= "($song)"; }
if ($artist && $song) { $title =~ s/\)\(/ : /; }

#------------------------------------------------------------------------------
print <<HTML;

<html>
<head>
    <META HTTP-EQUIV=Refresh CONTENT="30; URL=http://$host/cgi-bin/xm.cgi">
    <title>OpenXM - $title</title>
    <script language="Javascript">
    <!--   
	function sOpen() {
        window.open("sleep.cgi","","location=no,toolbar=no,menubar=no,scrollbars=no,resizable=yes,width=330,height=160");
    }
    //-->
</script>

</head>
<body bgcolor="#000000" text="#ffffff" link="#ffffff" vlink="#ffffff" alink="#ffffff"> 

HTML
#------------------------------------------------------------------------------

if (param('Go')) {
    print "Please Wait...\n";
    exit;

} elsif ($state eq '' || $state =~ /Off/) {
    print <<HTML;

<script language="Javascript">
<!--
function wOpen() {
    self.close();
    window.open("xm.cgi?Go=1&Power=ON0","","location=no,toolbar=no,menubar=no,scrollbars=no,resizable=yes,width=600,height=325");
}
//-->
</script>
<form>
<center>
<input type="button" onclick="wOpen()" value="Turn On Radio">
</center>
</form>
    
HTML
    
    exit;
}

#------------------------------------------------------------------------------
print <<HTML;

<TABLE BORDER='3' BGCOLOR='#336699'>
<TR>
  <TH COLSPAN='3'><font size="+1" color="#ffffff">OpenXM Remote Control</font></TH>
</TR>
<TR><TD>
<table border=1 bgcolor='#333333' cellpadding='3'>
  <tr><td><b>Station</b></td><td>$station_name ($channel_num)</td></tr>
HTML
#------------------------------------------------------------------------------

if ($artist =~ /\w/) { print "<tr><td><b>Artist</b></td><td>$artist</td></tr>\n"; }
if ($song =~ /\w/) { print "<tr><td><b>Song</b></td><td>$song</td></tr>\n"; }

#------------------------------------------------------------------------------
print <<HTML;

</table>
</TD><TD>
<table>
  <tr><td><font size="+2"><a href="xm.cgi?Go=1&ChanUp=1">
      <img border='0' src='http://$host/up_arrow.png'></a></font></td></tr>
  <tr><td>&nbsp;</td></tr>
  <tr><td><font size="+2"><a href="xm.cgi?Go=1&ChanDown=1">
      <img border='0' src='http://$host/down_arrow.png'></a></font></td></tr>
</table>
</TD><TD>

  <font color='white'><center><b>Favorites List</b></center></font>

HTML
#------------------------------------------------------------------------------

foreach my $chan (@favorites) {

    print $sock "xmCHA:NFO:$chan\n";
    my $res = <$sock>;

    my ($status, $command, $state, $mute, $nfo) = split /\|/,$res,5;
    my ($channel_num, $station_name, $channel_group, $artist, $song) 
       = split(/~/,$nfo,5);

    if ($chan ne $channel_num && $artist) { 
        print "<li><a href='xm.cgi?Go=1&Change_Channel=$chan'><font size='-1'>$station_name</a> - $artist : $song</font></li>\n";
    }
}

#------------------------------------------------------------------------------
print <<HTML;  

  </TD>
</TR>
<TR>
  <TD COLSPAN='2'>
  <form method='post'>
  <input type='hidden' name='Go' value='1'>
  Station Number: <input type='text' size='3' name='Change_Channel' maxlength='3'>
  <input type='submit' value='Change'>
  </TD>
  <TD>
  <TABLE BORDER=1 WIDTH="100%">
     <TR>
     <FORM>  
HTML
#------------------------------------------------------------------------------

if ($state =~ /On/) {
    if ($mute =~ /On/) {
	print "<TD ALIGN='left'><img src='http://$host/green_ball.png'> <a href='xm.cgi?Go=1&Mute=OFF'>Mute</a></TD>\n";
    } else {
	print "<TD ALIGN='left'><img src='http://$host/red_ball.png'> <a href='xm.cgi?Go=1&Mute=ON0'>Mute</a></TD>\n";
    }
    print "<TD ALIGN='center'><input type='button' onclick='sOpen()' value='Sleep Timer'></td>";
    print "<TD ALIGN='right'><img src='http://$host/green_ball.png'> <a href='xm.cgi?Go=1&Power=OFF'>Power</a></TD>\n";
}

#------------------------------------------------------------------------------
print <<HTML;
    </FORM>
    </TR>
  </TABLE>
  </TD>
</TR>
</TABLE>

<font size="-2">OpenXM &copy Copyright 2003, 2004 Christopher J. Carlson (c\@rlson.net)</font>

</body>
</html>
HTML

#------------------------------------------------------------------------------

close($sock);
