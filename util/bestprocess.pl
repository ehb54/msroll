#!/usr/bin/perl

$msrollcmd       = "/Users/eb/besttest/msroll/bin/msroll_xyzr";
$bestcmd         = "/Users/eb/bin/best";
$ussaxsutilcmd   = ". ~/ultrascan3-somo-dev/qt5env;~/ultrascan3-somo-dev/us_somo/bin/us_saxs_cmds_t.app/Contents/MacOS/us_saxs_cmds_t";

$startfine = .3;
$endfine   = 1;
$deltafine = 0.05;

$notes = "
usage: $0 beadmodel

name is the basename of the beadmodel
makes a directory for the processing (name)
converts bead model to name.xyzr
runs msroll using fineness [$startfine:$endfile:$deltafine]
stores c3p results in name_#triangles
runs best on each
digests best results to produce name.csv

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;
die "$f does not end in .bead_model\n" if $f !~ /\.bead_model/i;

$name = $f;
$name =~ s/\.bead_model$//i;

# die "can't make directory '$name' - already exists, please remove or rename\n" if -e $name;

mkdir $name;

## convert to xyzr

$bserial = 1;

open IN, $f;
$_ = <IN>;
@_ = split /\s+/, $_;
$beads = $_[0];
$out = '';

$mw = 0;

for ( $i = 1; $i <= $beads; ++$i ) {
    $_ = <IN>;
    $_ =~ s/^\s*//;
    @_ = split /\s+/, $_;

    $out .= "$_[0] $_[1] $_[2] $_[3] UNK $i UNKN\n";

    $mw += $_[4];
}

close IN;

print "beads $beads, mw $mw\n";

open OUT, ">$name/$name.xyzr";
print OUT $out;
close OUT;

chdir $name;

for ( $fine = $startfine; $fine <= $endfine; $fine += $deltafine ) {
    $ufine = "$fine";
    $ufine =~ s/\./_/g;
    $thisname = "${name}_f$ufine";
    $cmd = "$msrollcmd -m $name.xyzr -f $fine -t $thisname.c3p -p 0.0 2> $thisname.out";
    print "Starting msroll fineness $fine\n";
    print "$cmd\n";
    print `$cmd`;
    $triangles = `grep 'triangles written to disk' $thisname.out | awk '{ print \$1 }'`;
    chomp $triangles;
    print "triangles '$triangles'\n";
    print "Finished msroll - triangles $triangles\n";
    $ptriangles = '0'x(6-length("$triangles")) . $triangles;
    my $fo = "${thisname}_$ptriangles";
    print "$fo\n";
    `mv $thisname.c3p $fo`;

    $cmd = "$bestcmd -f $fo -mw $mw -vc 2";
    print "Starting best\n";
    print "$cmd\n";
    print `$cmd`;
    
    if ( !$? ) {
        my $bestout = "${fo}vcm.be";
        die "expected result $bestout does not exist\n" if !-e $bestout;
        if ( !-z $bestout ) {
            push @bestout, $bestout;
            push @triangles, $triangles;
        } else {
            warn "$bestout is empty, skipping\n";
        }
    } else {
        warn "best returned an error status\n";
    }
}

for ( $i = @bestout - 1; $i >= 0; --$i ) {
    print "$bestout[$i] $triangles[$i]\n";
}

$cmd = "$ussaxsutilcmd json '{\"bestcsv\":1,\"name\":\"$name\",\"files\":[\"";
$cmd .= join( "\",\"", reverse @bestout );
$cmd .= "\"],\"triangles\":[";
$cmd .= join( ",", reverse @triangles );
$cmd .= "]}'";

print "cmd\n$cmd\n----\n";

## ~/ultrascan3-somo-dev/us_somo/bin/us_saxs_cmds_t.app/Contents/MacOS/us_saxs_cmds_t json '{"bestcsv":1,"files":["L10_A_f0_95_000740vcm.be","L10_A_f0_9_000940vcm.be"],"triangles":[740,940],"name":"L10_A"}'
