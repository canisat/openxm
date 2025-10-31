# XMTracker.pm v1.3 - Perl Module to Interface XMFan.com's Tracker Page
#
# XMTracker.pm Copyright (C) 2004 Christopher J. Carlson <c@rlson.net>
#
# XMTracker.pm is part of the OpenXM Package.
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

package XMTracker;

use LWP::Simple qw($ua get);		# Used to do the HTTP Post
my $log_file = "XMTracker-error.log";

sub _log_err {
    my $err_msg = shift;
    
    open (LOG, ">>$log_file") or return 0;
    print LOG "$err_msg";
    close LOG;
    return 1;
}    

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my %args = @_;

    my $self = { };
    bless $self, $class;

    unless (defined ($args{server})) {	# Must Define Server in new
        warn "Can't call new without specifying a tracker server\n";
        _log_err("Can't call new without specifying a tracker server\n");
        return 0;
    }    	
    unless (defined ($args{un})) {	# Must Define Username in new
        warn "Can't call new without specifying a username\n";
        _log_err("Can't call new without specifying a username\n");
        return 0;
    }
    unless (defined ($args{pw})) {	# Must Define Password in new
        warn "Can't call new without specifying a password\n";
        _log_err("Can't call new without specifying a password\n");
        return 0;
    }
        
    $self->{un} = $args{un};		# Add server, un & pw to self Hash
    $self->{pw} = $args{pw};
    $self->{server} = $args{server};
        
    return $self;			# Return
}

sub update_tracker {
    my $self = shift;
    my %args = @_;

    unless (defined ($self->{un})) {	# Must have username defined.  Assume pw is also defined
        warn "Must call new before calling update_tracker\n";
        _log_err("Must call new before calling update_tracker\n");
        return 0;
    }
    
    unless (defined ($args{channel_num})) {	# Must have given at least a channel num
        warn "Must define \$channel_num in call\n";
        _log_err("Must define \$channel_num in call\n");
        return 0;
    }

    unless (defined($args{artist})) { $args{artist} = ''; }	# Could be off or may not
    unless (defined($args{song})) { $args{song} = ''; }		# have this info in chan desc
    
    $ua->timeout(5);						# Try for 5 secs or bail
    #my $tracker_server = 'http://tracker.xmfan.com/';		# XMTracker URL
    
    # We will build the tracker URL for post here.
    my $tracker_page = "now.php?u=".$self->{un}."&p=".$self->{pw};
    $tracker_page .= "&c=$args{channel_num}";
    $tracker_page .= "&a=$args{artist}";
    $tracker_page .= "&t=$args{song}";
    $tracker_page =~ s/ /%20/g;					# Replace space with %20 (URL Space)
    my $result = get("$self->{server}$tracker_page");		# Get Result using Post

    # Uncomment to have URL and Result in Log    
#    _log_err("URL: $self->{server}$tracker_page\n");
#    _log_err("RES: $result\n");
    
    if ($result ne "yep") {					# Ryan answers with yep if successful.
        warn "Error with XMTracker.  Check USERNAME & PASSWORD for $self->{server}.\n";
        _log_err("Error with XMTracker.  Check USERNAME & PASSWORD for $self->{server}.\n");
        return 0;
    }
}
1;