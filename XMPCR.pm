# XMPCR v1.3 - Perl Module used to control an XM PCR Radio.
#
# Copyright (C) 2003, 2004 Christopher J. Carlson <c@rlson.net>
#
# XMPCR is part of the OpenXM Package.
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
# David Broome and Nick Sayer helped provide a lot of the information relating
# to the hardware command strings.  Many thanks to both of them.
#
# Please send suggestions/comments to me at c@rlson.net.
# - cjc
#

package XMPCR;

my $is_windows;
if ($^O =~ /Win32/) {
    $is_windows = 1;
} else {
    $is_windows = 0;
}

use strict;

if ($is_windows) {
    require Win32::SerialPort;
} else {
    require Device::SerialPort;
}

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my %args = @_;

    my $self = { };
    bless $self, $class;

    unless (defined ($args{port})) {
        die "Can't call new without specifying a port\n";
    }

    $self->{_port} = $args{port};
    return $self;
}

sub _gethex {
    my %args = @_;
    my @ascii = unpack("H*", $args{hex});
    return join("",@ascii);
}

sub _open_port {
    my $self = shift;

    if ($is_windows) {
        $self->{PortObj} = new Win32::SerialPort ("$self->{_port}")
        || die "Can't open Serial Port! ($self->{_port} $!\n";
    } else {
        $self->{PortObj} = new Device::SerialPort ("$self->{_port}")
        || die "Can't open USB Port! ($self->{_port} $!\n";
    }
      
    $self->{PortObj}->baudrate(9600);
    $self->{PortObj}->parity("none");
    $self->{PortObj}->databits(8);
    $self->{PortObj}->stopbits(1);
    $self->{PortObj}->handshake("none");
    
    $self->{PortObj}->write_settings;       # New:  This fixes Win32 Platforms
      
    $self->port_state('Open');
    
    return $self;
}

sub port_state {
    my $self = shift;
    my $val  = shift;

    $self->{PortState} = $val if (defined($val));

    return $self->{PortState};
}

sub open_port {
    my $self = shift;

    $self->_open_port unless ($self->port_state() eq 'Open');
}

sub _close_port {
    my $self = shift;

    if ($self->{PortState} eq 'Open') {
        $self->{PortObj}->close;
        undef $self->{PortObj};         # New:  Used to deconstruct Port
    }
    $self->{PortState} = 'Closed';

    return $self;  
}

sub _port_write {
    my $self = shift;
    my ($msg, $rct) = @_;

    $self->open_port;
    $self->{PortObj}->write(pack("H*", $msg));
    $self->{PortObj}->read_const_time($rct) if (defined($rct));
}

sub _port_read {
    my $self  = shift;
    my $bytes = shift;

    $self->open_port;

    my $count = 0; my $result; my $timeout;
    while ($count < $bytes) {
    	if ($timeout > 30) { return 0; }
        ($count, $result) = $self->{PortObj}->read($bytes);
	$timeout++;
    }
    return _gethex(hex => $result);
}

sub power_on {
    my $self = shift;

    $self->open_port;
   
    # 5AA500 = START COMMAND STRING
    # 0 05 = Command Length
    # 1 00 = POWER ON COMMAND
    # 2 10 = Channel Label Size (8,10, or 16)
    # 3 10 = Channel Category Size (8, 10, or 16)
    # 4 24 = Artist & Title Size (8, 10, or 16)
    # 5 01 = Radio Type (1 = Power Not Constant; 0 = Hardwired Power)
    # EDED = END COMMAND STRING
    # Returns 33/40 Bytes; 33 = Not Activated.  40 = Activated.
   
    $self->_port_write('5AA500050010102401EDED', 100);
    $self->{Debug1}  = $self->_port_read(40);

    if ($self->{Debug1} == 0) {
        # Radio Probably not Activated...
        $self->_port_write('5AA500050010102401EDED', 100);
        $self->{Debug1}  = $self->_port_read(33);
        $self->{Activated} = 0;
    } else {
        $self->{Activated} = 1;
    }

    unless (substr($self->{Debug1},0,6) eq '5aa500') {
       die "Error Initializing Radio!\n";
    }
    $self->{RadioID} = pack("H*", substr($self->{Debug1}, 46, 16)); 
    $self->{State}   = 'On';
    $self->{Mute} = 'Off';
    
    #Note:  This is the Service ID, not channel num
    $self->{LastChan} = hex(substr($self->{Debug1},26,2));
    
    $self->{SDEC_Version} = substr($self->{Debug1},16,2);
    $self->{XMSTK_Version} = substr($self->{Debug1},34,2);

    my $str_date = substr($self->{Debug1}, 18,8);
    $str_date =~ m/(\d{2})(\d{2})(\d{4})/;
    $self->{SDEC_Date} = "$1\-$2\-$3";
    
    $str_date = substr($self->{Debug1}, 36,8);
    $str_date =~ m/(\d{2})(\d{2})(\d{4})/;
    $self->{XMSTK_Date} = "$1\-$2\-$3";
    
    # Set to Preview if LastChan returns 0
    if ($self->{LastChan} == 0) { $self->{LastChan} = 1; }
    
    return 1;
}

sub channel_to_service {
    my $self = shift;
    my $chan = shift;
    
    $self->chan_info(channel => $chan);
    return $self->{ServiceID};
}


sub power_off {
    my $self = shift;

    if ($self->{State} eq 'On') {
        
        # 5AA500 = START COMMAND STRING
        # 0 02 = Command Length
        # 1 01 = POWER OFF COMMAND
        # 5 00 = Power Off Type (1 = Sleep Mode; 0 = Off Mode)
        # EDED = END COMMAND STRING
        
        $self->_port_write('5AA500020100EDED');
    }
    $self->{State} = 'Off';

    $self->_close_port;
}

sub get_radioID {
    my $self = shift;
    
    # 5AA500 = START COMMAND STRING
    # 0 01 = Command Length
    # 1 31 = RADIO ID COMMAND
    # EDED = END COMMAND STRING
    
    $self->_port_write('5AA5000131EDED');
    $self->{DebugRadioID} = $self->_port_read(18); 
    $self->{RadioID} = pack("H*", substr($self->{DebugRadioID}, 16, 16));
}

sub mute_on {
    my $self = shift;

    # 5AA500 = START COMMAND STRING
    # 0 02 = Command Length
    # 1 13 = MUTE COMMAND
    # 2 01 = Mute On/Off (1 = On; 0 = Off)
    # Returns 10 Bytes
    
    $self->_port_write('5AA500021301EDED');
    $self->{DebugMute}  = $self->_port_read(10);
   
    $self->{Mute} = 'On';
}

sub mute_off {
    my $self = shift;

    # See mute_on

    $self->_port_write('5AA500021300EDED');
    $self->{DebugMute}  = $self->_port_read(10);
   
    $self->{Mute} = 'Off';
}

sub chan_info {
    my $self = shift;
    my %args = @_;

    my $chan = $args{channel} || $self->{CurrentChannel};

    $chan = sprintf("%x", $chan);
    if (length($chan) == 1)  { $chan = "0$chan"; }
    $chan = uc($chan);

    # 5AA500 = START COMMAND STRING
    # 0 04 = Command Length
    # 1 25 = CHANNEL LIST COMMAND
    # 2 08 = Selection Method (8: Label Channel Select)
    #                         (9: Label Channel Next)
    # 3 XX = Channel Number (hex)
    # 4 00 = Program Type (?)
    # EDED = END COMMAND STRING
    # Returns 83 Bytes

    my $chan_str = "5AA500042508".$chan."00EDED";
    $self->_port_write($chan_str, 100);
    $self->{Debug2} = $self->_port_read(83);		# Broken Sometimes... Causes Lockup.. Timeout??

    unless (substr($self->{Debug2},0,6) eq '5aa500') {
        warn "Error Fetching Channel Information!\n";
    }

    $self->{ServiceID}       = hex(substr($self->{Debug2}, 16,2));
    $self->{StationName}     = pack("H*", substr($self->{Debug2}, 20, 32));
    $self->{StationCategory} = pack("H*", substr($self->{Debug2}, 56, 32));
    $self->{Artist}          = pack("H*", substr($self->{Debug2}, 90, 32));
    $self->{Song}            = pack("H*", substr($self->{Debug2}, 122, 32));

    # Remove Trailing Whitespace (now by default)
    $self->{StationName} =~ s/\s*$//;
    $self->{StationCategory} =~ s/\s*$//;
    $self->{Artist} =~ s/\s*$//;
    $self->{Song} =~ s/\s*$//;
}

sub tech_info {
    my $self = shift;

    # 5AA500 = START COMMAND STRING
    # 0 01 = Command Length
    # 1 43 = TECH COMMAND
    # EDED = END COMMAND STRING 
    # Returns 32 Bytes

    $self->_port_write('5AA5000143EDED', 100);
    
    $self->{Debug3} = $self->_port_read(32);

    unless (substr($self->{Debug3},0,6) eq '5aa500') {
        warn "Error Fetching Technical Info\n";
    }
 
    $self->{SigStat}	= substr($self->{Debug3}, 14,2);    # 0 - 3; 0 = Bad; 3 = Good
    $self->{AntStat}	= substr($self->{Debug3}, 16,2);    # 0 or 3; 0 = None, 3 = Present

    $self->{Sat1Demod}	= substr($self->{Debug3}, 18,2);    # 1 = Locked; 0 = Not Locked
    $self->{Sat2Demod}	= substr($self->{Debug3}, 20,2);
    $self->{TerDemod}	= substr($self->{Debug3}, 22,2);

    $self->{Sat1TDM}	= substr($self->{Debug3}, 24,2);
    $self->{Sat2TDM}	= substr($self->{Debug3}, 26,2);
    $self->{TerTDM}	= substr($self->{Debug3}, 28,4);

    $self->{Sat1BER}    = hex(substr($self->{Debug3}, 32,4));
    $self->{Sat2BER}	= hex(substr($self->{Debug3}, 36,4));
    $self->{TerBER}	= hex(substr($self->{Debug3}, 40,4));
    
    $self->{SatAGC}	= hex(substr($self->{Debug3}, 52,2));
    $self->{TerAGC}	= hex(substr($self->{Debug3}, 54,2));

    $self->{Sat1CN}	= (substr($self->{Debug3}, 56,2)/4);
    $self->{Sat2CN}	= (substr($self->{Debug3}, 58,2)/4);

    # Calculate Sat Percent
    
    my $satdb = 0;
    if ($self->{Sat1CN} > $self->{Sat2CN}) {
        $satdb = $self->{Sat1CN};
    } else {
        $satdb = $self->{Sat2CN};
    }
    
    if ($satdb < 12) {
        $self->{SatPercent} = $satdb * 80 / 12;
    } elsif ($satdb < 16) {
        $self->{SatPercent} = ((($satdb - 48) * 20 / 4) + 80);
    } else {
        $self->{SatPercent} = 99.9;
    }
    
    # Calculate Ter Percent
    
    my $tersig = ($self->{TerBER} / 68);
    $tersig *= 10;
    $tersig = 100 - $tersig;

    if ($tersig <= 0) { $self->{TerPercent} = 0 }
    elsif ($tersig >= 100) {$self->{TerPercent} = 100}
    else { ($self->{TerPercent} = $tersig); }

    $self->{TerSig} = $tersig;
    
    return $self;
}

sub valid_channel {
    my $self = shift;
    my %args = @_;

    if ($self->{ChanList}->{$args{channel}}) {
        return 1;
    } else {
        return 0;
    }
}


sub change_channel {
    my $self = shift;
    my %args = @_;

    unless ($args{channel}) {
       warn "Must specify a channel number\n";
       return 0;
    }

    unless ($self->{ChanList}->{$args{channel}}) {
       warn "Channel $args{channel} Does Not Exist\n";
       return 0;
    }

    my $chan = $args{channel};

    $chan = sprintf("%02X", $chan);

    # 5AA500 = START COMMAND STRING
    # 0 06 = Command Length
    # 1 10 = CHANNEL CHANGE COMMAND
    # 2 02 = Selection Method (Select Method?)
    # 3 XX = Channel Number (hex)
    # 4 00 = Unknown (0: Audio; 1: Data)
    # 5 00 = Program Type
    # 6 01 = Routing (1: Audio Port)
    # EDED = END COMMAND STRING
    # Returns 12 Bytes

    my $chan_str = "5AA500061002${chan}000001EDED";

    $self->_port_write($chan_str, 3000);

    my $result = $self->_port_read(12);

    $self->{PreviousChannel} = $self->{CurrentChannel};
    $self->{CurrentChannel} = $args{channel};
    $self->chan_info;

}

sub channel_up {
    my $self = shift;

    my $new_chan = $self->{CurrentChannel} + 1;

    until ($self->{ChanList}->{$new_chan}) {
        $new_chan++;
        if ($new_chan > 255) { $new_chan = 1; last; }   
    }

    $self->change_channel(channel => $new_chan);
}

sub channel_down {
    my $self = shift;

    my $new_chan = $self->{CurrentChannel} - 1;

    if ($new_chan < 1) { $new_chan = 255; }

    until ($self->{ChanList}->{$new_chan}) {
        $new_chan--;
    }

    $self->change_channel(channel => $new_chan);
}

sub get_all {
    my $self = shift;
   
    # 5AA500 = START COMMAND STRING
    # 0 04 = Command Length
    # 1 25 = CHANNEL LIST COMMAND
    # 2 09 = ?
    # 3 00 = ?
    # 4 00 = ?
    # EDED = END COMMAND STRING
    # Returns 83 Bytes

    my $get_str = "5AA5000425090000EDED";

    $self->_port_write($get_str, 100);
    my $result = $self->_port_read(83);
    my $ack =  substr($result, 14, 2);

    $self->{ChanList} = {};

    while ($ack ne '00') {
        my $chan_num = hex($ack);    # Get Decimal Value of Channel

        $self->{ChanList}->{$chan_num}->{ServiceID} = hex(substr($result, 16,2));
        $self->{ChanList}->{$chan_num}->{ChanName} = pack("H*", substr($result, 20, 32));
        $self->{ChanList}->{$chan_num}->{ChanCategory} = pack("H*", substr($result, 56,32));
        $self->{ChanList}->{$chan_num}->{SongName} = pack("H*", substr($result, 122,32));
        $self->{ChanList}->{$chan_num}->{Artist} = pack("H*", substr($result, 90,32));
        $self->{ChanList}->{$chan_num}->{Valid} = 1;

	# Remove Trailing Whitespace (now by default)
        $self->{ChanList}->{$chan_num}->{ChanName} =~ s/\s*$//;
        $self->{ChanList}->{$chan_num}->{ChanCategory} =~ s/\s*$//;
        $self->{ChanList}->{$chan_num}->{SongName} =~ s/\s*$//;
        $self->{ChanList}->{$chan_num}->{Artist} =~ s/\s*$//;

        my $ack_str = "5AA500042509${ack}00EDED";
        $self->_port_write($ack_str, 100);
        $result = $self->_port_read(83);
        $ack =  substr($result, 14, 2);
    }
}

1;

