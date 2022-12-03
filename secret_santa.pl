#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);

use List::Util qw(shuffle);
use Encode qw(encode);
use Email::Stuffer;
use Email::Valid;
use Email::Sender::Transport::SMTP ();

my ($dryrun, $verb, $file, $couples);

my ($smtphost, $smtpport) = ('smtp.gmail.com', 587);
my ($smtpuser, $smtppass) = ('yourgmail', 'yourpassword');

GetOptions(
    'v|verbose'   => \$verb,
    'p|people=s'  => \$file,
    'c|couples=s' => \$couples,
    'n|dryrun'    => \$dryrun
) or die "Usage: $0 -p|--people FILENAME [-c|--couples FILENAME -v|--verbose -n|--dryrun]";

defined $file or die "Usage: $0 -p|--people FILENAME [-c|--couples FILENAME -v|--verbose -n|--dryrun]";


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

if ($verb) {
    print "Processed contacts:\n";
    foreach my $name (keys %contacts) {
        print("\t$name\t$contacts{$name}\n")
    }
}

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

print "Creating pairings for presents.... if it takes too long, Ctrl+C and start over\n";
print "Trial run, not sending emails\n" if ($dryrun);

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

print "Done pairing, sending emails....\n";

foreach my $from (keys %draw) {

    if ($verb) {
        print "Emailed $contacts{$from} about their present for $draw{$from}\n";
    }
}

if (!$dryrun) {
    my $transport = Email::Sender::Transport::SMTP->new({
        host          => $smtphost,
        port          => $smtpport,
        ssl           => 'starttls',
        sasl_username => $smtpuser,
        sasl_password => $smtppass
    });

    foreach my $from (keys %draw) {
        my $to = $draw{$from};
        my $body = email_body($from, $to);

        Email::Stuffer->from     ('santa@northpole.org')
                      ->to       ($contacts{$from})
                      ->subject  ('Secret Santa')
                      ->text_body(encode('UTF-8', $body))
                      ->transport('SMTP', { host => 'localhost' }) #$transport)
                      ->send;
    }
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

./secret_santa -p|--people [-c|--couples -v|--verbose -n|--dryrun]

=head1 DESCRIPTION

Generates Secret Santa pairs and sends emails to people in the list

=head1 ARGUMENTS

=over

=item -p, --people

A file containing the list of people to participate, name and email separated by a space, one per line

=item -c, --couples

A file containing the list of couples that should not be matched, two names separated by a space, one per line

=item -v, --verbose

Print out the pairs and the progress of the script to the console

=item -n, --dryrun

Run the script without sending emals, to test it works.

=back

=cut

