#!/usr/bin/perl

$msrollcmd       = "/Users/eb/besttest/msroll/bin/msroll_xyzr";
$bestcmd         = "/Users/eb/bin/bestnotty";
$ussaxsutilcmd   = ". ~/ultrascan3-somo-dev/qt5env;~/ultrascan3-somo-dev/us_somo/bin/us_saxs_cmds_t.app/Contents/MacOS/us_saxs_cmds_t";
$c3p2bmcmd       = "../c3p2beadmodel.pl";
$maxproc         = 4;
$maxtriangles    = 6000;

$startfine = .2;
$endfine   = 1;
$deltafine = 0.02;

$notes = "
usage: $0 beadmodel

name is the basename of the beadmodel
makes a directory for the processing (name)
converts bead model to name.xyzr
runs msroll using fineness [$startfine:$endfile:$deltafine]
stores c3p results in name_#triangles
creates bead models from c3p
runs best on each
digests best results to produce name.csv

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;
die "$f does not end in .bead_model\n" if $f !~ /\.bead_model/i;

$name = $f;
$name =~ s/\.bead_model$//i;

die "can't make directory '$name' - already exists, please remove or rename\n" if -e $name;

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
    $fine = sprintf( "%.3f", $fine );
    $ufine = "$fine";
    $ufine =~ s/\./_/g;
    $thisname = "${name}_f$ufine";
    my $cmd = "$msrollcmd -m $name.xyzr -f $fine -t $thisname.c3p -p 0.0 2> $thisname.out";
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

    $cmd = "perl ../c3p2beadmodel.pl $fo > $fo.bead_model";
    print "$cmd\n";
    print `$cmd\n`;
    die "cmd error $?\n" if $?;

    if ( $triangles <= $maxtriangles ) {

        $cmd = "$bestcmd -f $fo -mw $mw -vc 2";
        # print "$cmd\n";
        $bestcmds{ $fo } = $cmd;
        $besttriangles{ $fo } = $triangles;
    } else {
        warn "too many triangles, skipping $fo\n";
    }
}

$cmds = "";

sub triangle_val {
    my $v = $_[0];
    $v =~ s/^.*_0*//g;
    $v =~ s/vcm\.be$//;
    return $v;
}

for my $fo ( sort { triangle_val( $b ) <=> triangle_val( $a ) } keys %bestcmds ) {
    $cmds .= $bestcmds{ $fo } . "&\n";
    if ( !(++$procs % $maxproc ) ) {
        $cmds .= "wait\n";
    }
}
$cmds .= "wait\n";

die "testing\n";

print "Starting best in parallel with $maxproc processes\n";
print $cmds;
print `$cmds`;
print "Ending best\n";

for my $fo ( keys %bestcmds ) {
    $triangles = $besttriangles{ $fo };
    
    my $bestout = "${fo}vcm.be";
    die "expected result $bestout does not exist\n" if !-e $bestout;
    if ( !-z $bestout ) {
        push @bestout, $bestout;
        push @triangles, $triangles;
    } else {
        warn "$bestout is empty, skipping\n";
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
