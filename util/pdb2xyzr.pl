#!/usr/bin/perl

use File::Basename;
my $dirname = dirname(__FILE__);

$notes = "usage: $0 pdb

converts atoms lines of pdb to xyzr
    ";

require "$dirname/pdbutil.pm";


$f = shift || die $notes;
die "$f does not exist\n" if !-e $f;

open $fh, $f || die "$f open error $!\n";
@l = <$fh>;
close $fh;

$bserial = 1;

foreach $l ( @l ) {
    my $r = pdb_fields( $l );
    next if $r->{"recname"}  !~ /^(ATOM|HETATM)$/;

    my $x       = $r->{x};
    my $y       = $r->{y};
    my $z       = $r->{z};
    my $resname = $r->{resname};
    my $name    = $r->{name};
    my $serial  = $r->{serial};

    my $r       = 1.5;

    #    print "$x $y $z $r $resname $serial $name\n";
    print "$x $y $z $r UNK $bserial UNKA\n";
    $bserial++;
}
