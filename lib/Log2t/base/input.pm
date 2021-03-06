#################################################################################################
#		INPUT MODULE
#################################################################################################
# This is the parent or super class of the input module.  It is possible to make new input
# modules inheret this class to make the writing of a new module easier (lazyness)
#
#
# Author: Kristinn Gudjonsson
# Version : 0.1
# Date : 01/05/11
#
# Copyright 2009-2011 Kristinn Gudjonsson (kristinn ( a t ) log2timeline (d o t) net)
#
#  This file is part of log2timeline.
#
#    log2timeline is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    log2timeline is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with log2timeline.  If not, see <http://www.gnu.org/licenses/>.

package Log2t::base::input;

use strict;

#use Log2t::Numbers;	# work with numbers, round-up, etc...
#use Log2t::Network;	# some routines that deal with network information
use Log2t::BinRead;  # to work with binary files (during verification all files are treaded as such)
use Log2t::Common ':binary';

#use Log2t::Time;	# for time manipulations
#use Log2t:Win;		# for few Windows related operations, GUID translations, etc..
#use Log2t:WinReg;	# to recover deleted information from registry
use vars qw($VERSION);

# version number
$VERSION = '0.1';

# by default these are the global varibles that get passed to the module
# by the engine.
# These variables can therefore be used in the module without needing to
# do anything to initalize them.
#
#	$self->{'debug'}	- (int) Indicates whether or not debug is turned on or off
#	$self->{'quick'} 	- (int) Indicates if we will like to do a quick verification
#	$self->{'tz'}		- (string) The timezone that got passed to the tool
#	$self->{'temp'}		- (string) The name of the temporary directory that can be used
#	$self->{'sep'} 		- (string) The separator used (/ in Linux, \ in Windows for instance)
#

sub new() {
    my $class = shift;

    # bless the class ;)
    my $self = bless {}, $class;

    # indicate that this is a text based file, with one line per call to get_time
    #	This option determines the behaviour of the engine. If this variable is set
    # 	to 0 it means that we return a single hash that contains multiple timstamp objects
    #	Setting it to 1 means that we return a single timesetamp object for each line that
    # 	contains a timestamp in the file.
    #
    # 	So if this is a traditional log file, it is usually better to leave this as 1 and
    # 	process one line at a time.  Otherwise the tool might use too much memory and become
    #	slow (storing all the lines in a large log file in memory might not be such a good idea).
    #
    #	However if you are parsing a binary file, or a file that you know contains few timestamps
    # 	in it, it might make more sense to just parse the entire file and return a single value
    #	instead of making the engine call the module in a loop.
    $self->{'multi_line'} = 1;

    $self->{'type'} = 'file';    # it's a file type, not a directory
    $self->{'file_access'} =
      0;    # do we need to parse the actual file or is it enough to get a file handle

    return $self;
}

# 	init
#
# The init call resets all variables that are global and might mess up with recursive
# scans.  It also loads the file itself
sub init() {
    my $self = shift;

   # there shouldn't be any need to create any global variables.  It might be best to
   # save all such variables inside the $self object
   # Creating such a variable is very simple:
   #	$self->{'new_variable'} = 'value'
   #
   # sometimes it might be good to initialize these global variables, to make sure they
   # are not used again when parsing a new file.
   #
   # This method, init, is called by the engine before parsing any new file.  That makes
   # this method ideal to initialize or null the values of global variables if they are used.
   # This is especially cruical when recursive parsing is used, to make sure that when the next file
   # is being parsed by the module there isn't any mix-up between files.

    return 1;
}

# 	get_version
# A simple subroutine that returns the version number of the format file
# There shouldn't be any need to change this routine, it serves its purpose
# just the way it is defined right now.
#
# @return A version number
sub get_version() {
    return $VERSION;
}

# 	get_description
# A simple subroutine that returns a string containing a description of
# the funcionality of the format file. This string is used when a list of
# all available format files is printed out
# @return A string containing a description of the format file's functionality
sub get_description() {

    # change this value so it reflects the purpose of this module
    return "Parse the content of a X log file";
}

#	end
# A subroutine that closes everything, remove residudes if any are left
# @return An integer indicating that the end operation was successful
sub end() {
    my $self = shift;

    # there might be some resources that need to be closed, for instance
    # some temporary files created by the module that need to be deleted,
    # or database connections closed or any other possible operations that
    # need to be performed to successfully close the file before it is possible
    # to start parsing the next one.
    #
    # This method is used for that, so if there is a need to close some
    # connections, do it here.
    #
    # It is not necessary to close the file handle though, that is done in
    # the main engine, not unless the module has created its own using the
    # file name that got passed to it, then it might be necessary to close it
    # here
    return 1;
}

#	get_time
# This is the main "juice" of the input module. It parses the input file
# and produces a timestamp object that get's returned
#
# @return Returns a array containing the needed values to print a body file
sub get_time() {
    my $self = shift;

    # the timestamp object
    my %t_line;
    my $text;
    my $date;

    # get the filehandle and read the next line
    return undef unless defined $self->{'file'};
    my $fh = $self->{'file'};
    my $line = defined(<$fh>) or return \%t_line;

    # check line, to see if there are any comments or other such non-related stuff
    if ($line =~ m/^#/) {

        # comment, let's skip that one
        return \%t_line;
    }
    elsif ($line =~ m/^$/ or $line =~ m/^\s+$/) {

        # empty line
        return \%t_line;
    }

    # substitute multiple spaces with one for splitting the string into variables
    $line =~ s/\s+/ /g;

    # some parsing done here ....
    $text = substr $line, 10, 10;

# The timestamp object looks something like this:
# The fields denoted by [] are optional and might be used by some modules and not others.
# The extra field gets in part populated by the main engine, however some fields might be created in the module,
# for instance if it is possible to extract the username it gets there, or the hostname. Other values might be
# source ip (src-ip) or some other values that might be of interest yet are not part of the main variables.
# Another interesting field that might be included in the extra field is the URL ('url').  If it is possible to
# show the user where he or she can get additional information regarding the event that is being produced
# this is a good place to put it in, for example Windows events found inside the Windows Event Log contain
# valuable information that can be further read... so in the evt.pm module a reference to the particular event is
# placed inside this variable:
#   $t_line{'extra'}->{'url'} =http://eventid.net/display.asp?eventid=' . $r{evt_id} . '&source=' . $source
#
# %t_line {
#               index
#                       value
#                       type
#                       legacy
#       desc
#       short
#       source
#       sourcetype
#       version
#       [notes]
#       extra
#               [filename]
#               [md5]
#               [mode]
#               [host]
#               [user]
#               [url]
#               [size]
#               [...]
# }
#

    # create the t_line variable
    %t_line = (
        'time'   => { 0 => { 'value' => $date, 'type' => 'Time Written', 'legacy' => 15 } },
        'desc'   => $text,
        'short'  => $text,
        'source' => 'LOG',
        'sourcetype' => 'This log file',
        'version'    => 2,
        'extra'      => { 'user' => 'username extracted from line' }
              );

    return \%t_line;
}

#	get_help
# A simple subroutine that returns a string containing the help
# message for this particular format file.
# @return A string containing a help file for this format file
sub get_help() {

    # this message contains the full message that gest printed
    # when the user calls for a help on a particular module.
    #
    # So this text that needs to be changed contains more information
    # than the description field.  It might contain information about the
    # path names that the file might be found that this module parses, or
    # URLs for additional information regarding the structure or forensic value of it.
    return "This parser parses the log file X and it might be found on location Y.";
}

#	verify
# A subroutine that reads a single line from the log file and verifies that it is of the
# correct format so it can be further processed.
# The correct format of a Squid access file (with httpd_emulate equal to off) is:
# timestamp elapsed IP/Client Action/Code Size Method URI Ident Hierarchy/From Content
# @return An array containing an integer and a string.  The integer indicates a success or failure and the
#	string is the error message (if the file is not correctly formed)
sub verify {
    my $self = shift;

    # define an array to keep
    my %return;
    my $line;
    my $temp;
    my $tag;

# defines the maximum amount of lines that we read until we determine that this is not the log file of question
    my $max = 15;
    my $i   = 0;

    $return{'success'} = 0;
    $return{'msg'}     = 'success';

    # start by setting the endian correctly
    Log2t::BinRead::set_endian(LITTLE_E);

    my $ofs = 0;

    # open the file (at least try to open it)
    eval {
        unless ($self->{'quick'})
        {

            # a firewall log file should start with a comment, or #, let's verify that
            seek($self->{'file'}, 0, 0);
            read($self->{'file'}, $temp, 1);
            $return{'msg'} = 'Wrong magic value';
            return \%return unless $temp eq '#';
        }

        $tag = 1;

        # begin with finding the line that defines the fields that are contained
        while ($tag) {
            $tag = 0
              unless $line = Log2t::BinRead::read_ascii_until($self->{'file'}, \$ofs, "\n", 400);
            $tag = 0 if $i++ eq $max;    # check if we have reached the end of our attempts
            next unless $tag;

            $line =~ s/\n//;
            $line =~ s/\r//;

            if ($line =~ m/^magic_quote/) {
                $tag = 0;

                # read the line to get the number of fields
                $line =~ s/\s+/ /g;

                $return{'success'} = 1;
            }
        }
    };
    if ($@) {
        $return{'success'} = 0;
        $return{'msg'}     = "Unable to process file ($@)";

        return \%return;
    }

    return \%return;
}

1;

__END__

=pod

=head1 NAME

structure - An example input module for log2timeline

=head1 METHODS

=over 4

=item new

A default constructor for the input module. There are no parameters passed to the constructor, however it defines the behaviour of the module.  That is to say it indicates whether or not this module parses a file or a directory, and it also defines if this is a log file that gets parsed line-by-line or a file that parses all the timestamp objects and returns them all at once.

=item init

A small routine that takes no parameters and is called by the engine before a file is parsed.  This routine takes care of initializing global variables, so that no values are stored from a previous file that got parsed by the module to avoid confusion.

=item end

Similar to the init routine, except this routine is called by the engine when the parsing is completed.  The purpose of this routine is to close all database handles or other handles that got opened by the module itself (excluding the file handle) and to remove any temporary files that might still be present.

=item get_time

This is the main routine of the module.  This is the routine that parses the actual file and produces timestamp objects that get returned to the main engine for further processing.  The routine reads the file or directory and extracts timestamps and other needed information to create a timestamp object that then gets returned to the engine, either line-by-line or all in one (as defined in the constructor of the module).

=item verify

The purpose of this routine is to verify the structure of the file or directory being passed to the module and tell the engine whether not this module is capable of parsing the file in question or not. This routine is therfore very important for the recursive search of the engine, and it is very important to make this routine as compact and optimized as possible to avoid slowing the tool down too much.

=item get_help()

Returns a string that contains a longer version of the description of the output module, as well as possibly providing some assistance in how the module should be used.

=item get_version()

Returns the version number of the module.

=item get_description()

Returns a string that contains a short description of the module. This short description is used when a list of all available modules is printed out.

=back

=cut

