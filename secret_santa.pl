#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);

use List::Util qw(shuffle);

use Email::Valid;

use utf8::all;
use Encode qw(encode);

use MIME::Lite;

my ($verb, $file, $couples);

GetOptions(
    'v|verbose'   => \$verb,
    'p|people=s'  => \$file,
    'c|couples=s' => \$couples,
) or die "Usage: $0 -p|--people FILENAME [-c|--couples FILENAME -v|--verbose]";

defined $file or die "Usage: $0 -p|--people FILENAME [-c|--couples FILENAME -v|--verbose]";


open INFILE, "<", $file;

my (@bag, %contacts, %dont_match);

while (<INFILE>) {
    chomp;

    /^ \w+ \s [\w\.]+@[\w\.]+ $/ix or die "Malformed file $file, needs to be \nname name\@host.com\n";

    my ($name, $email) = split / /;
    Email::Valid->address($email) or die "Malformed email address $email\n";

    $contacts{$name} = $email;
    push @bag, $name;
}

close INFILE;

if (defined $couples) {
    open INFILE, "<", $couples;

    while (<INFILE>) {
        chomp;

        /^ \w+ \s \w+ $/ix or die "Malformed file $couples, needs to be \nname1 name2\n";

	my ($name1, $name2) = split / /;

        $name1 ~~ @bag and $name2 ~~ @bag or die "Malformed file $couples, all names need to be in $file\n";

	$dont_match{$name1} = $name2;
	$dont_match{$name2} = $name1; 
    }

}

if ($verb) {
    foreach my $name (keys %dont_match) {
        my $name1 = $dont_match{$name};
        print "$name must not buy for $name1\n";
    }
}

my %draw;

TRY: while () {
    foreach my $name (my @copy = @bag) {
        @bag = shuffle @bag;

        my $pick = shift @bag;
        
	# a person can't pick themselves or their partner
	while ( ($pick eq $name) or 
		(defined $dont_match{$name} and $pick eq $dont_match{$name}) ) {
            # last person, try again
            if (@bag == 0) {
                @bag = @copy;
                next TRY;
            }
            push @bag, $pick;
            my $pick = shift @bag;
	}

        $draw{$name} = $pick;
    }
    last TRY;
}

if ($verb) {
    foreach my $name (keys %draw) {
        my $pick = $draw{$name};
        print "$name will buy a present for $pick\n";
    }
}

print "Done pairing, sending emails....";

foreach my $from (keys %draw) {

    my $to = $draw{$from};

    my $body = email_body($from, $to);

    if ($verb) {
        print "Emailed $contacts{$from} about their present for $to\n";
    }
    
    my $msg = MIME::Lite->new(
        From     => 'santa@northpole.com',
        To       => $contacts{$from},
        Subject  => 'Secret Santa',
        Data     => encode('UTF-8', $body),
        Type     => 'text/plain; charset=UTF-8',
        Encoding => '8bit',
    );

    $msg->send;
}

exit;

sub email_body {
    my ($from, $to) = @_;

    return <<EOF;
Greetings, $from!

For this year's Secret Santa, you will be buying for: $to

The guide price is £10. Gifts will be exchanged on Christmas Day.

Please contact Santa's Little Helpers with any queries.

Best wishes,

Santa
EOF
}



=head1 NAME

secret_santa

=head1 SYNOPSIS

./secret_santa -p|--people [-c|--couples -v|--verbose]

=head1 DESCRIPTION

Generates Secret Santa pairs and sends emails to people in the list

=head1 ARGUMENTS

=over

=item -v, --verbose

Print out the pairs to the console

=item -p, --people

A file containing the list of people to participate, name and email separated by a space, one per line

=item -c, --couples

A file containing the list of couples that should not be matched, two names separated by a space, one per line

=back

=cut

