#!/usr/bin/perl

$notes = "
usage: $0 filename

converts c3p to bead model file

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;

open IN, $f;

$_ = <IN>;

@_ = split /\s+/, $_;
$beads = $_[0];
$out = "$beads 0\n";

for ( $i = 0; $i < $beads; ++$i ) {
    $_ = <IN>;
    $_ =~ s/^\s*//;
    @_ = split /\s+/, $_;
#    print ( join ':', @_ );
#    print "\n";
#    die "\n";
    $out .= "$_[0] $_[1] $_[2] 0.05 1 1 x 1\n";
}

$out .= "\n";
$out .= "Current model scale (10^-x m) (10 = Angstrom, 9 = nanometer), where x is : 10\n";

print $out;
