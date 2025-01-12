#!/usr/bin/perl

$msrollcmd       = "~/srv/besttests/msroll/bin/msroll_xyzr";
$msdrawcmd       = "~/srv/besttests/msroll/bin/msdraw";
$bestcmd         = "~/srv/besttests/best/bin/best";
$rcoalcmd        = "~/srv/besttests/best/bin/rcoal";
$ussaxsutilcmd   = "env LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/home/ehb/ultrascan3/lib:/opt/qt-5.15.13/lib:/opt/qt-5.15.13-qwt-6.1.6/lib ~/ultrascan3/us_somo/bin64/us_saxs_cmds_t";
$c3p2bmcmd       = "~/srv/besttests/msroll/util/c3p2beadmodel.pl";
$maxproc         = 48;
$maxtriangles    = 10000;

$startfine   = .3;
$endfine     = 1;
$deltafine   = 0.05;
$proberadius = "1.5";
$global_nmin = 3000;
$global_nmax = 6000;
# for smaller bead tests
#$global_nmin = 300;
#$global_nmax = 600;
$maxmodels    = 25;

$notes = "
usage: $0 {options} beadmodel

options: -r use rcoal

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
if ( $f eq '-r' ) {
    $rcoal++;
    $f = shift || die $notes;
}

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
    $thisname = "${name}_f${ufine}";

    ## run msroll

    my $cmd = "$msrollcmd -m $name.xyzr -f $fine -t $thisname.c3p -v $thisname.c3v -p $proberadius 2> $thisname.out";
    print "Starting msroll fineness $fine\n";
    print "$cmd\n";
    print `$cmd`;
# msroll always seems to return a failure status
#    if ( $? ) {
#        warn "msroll returned status $? with fineness $fine\n";
#        # next;
#    }
    $triangles = `grep 'triangles written to disk' $thisname.out | awk '{ print \$1 }'`;
    chomp $triangles;
    print "triangles '$triangles'\n";
    print "Finished msroll - triangles $triangles\n";

    if ( !($triangles > 0 ) ) {
        warn "msroll returned zero triangles with fineness $fine, skipping\n";
        next;
    }

    ## optionally use rcoal

    my $fo;

    if ( $rcoal ) {
        my $nmin = int( $triangles * .8 );
        my $nmax = $triangles;
        $nmin = $global_nmin if $global_nmin;
        $nmax = $global_nmax if $global_nmax;
        my $cmd = '';
        my $char23name  = substr( $thisname, 0, 23 );
        my $char26name  = substr( $thisname, 0, 26 );
        if ( $char23name ne $thisname ) {
            $cmd .= "cp $thisname.c3v $char23name.c3v; "; 
        }
        $cmd .= "$rcoalcmd -f $thisname.c3p -nmax $nmax -nmin $nmin -n 6 2>&1 > ${thisname}_rcoal.out";
        print "$cmd\n";
        print `$cmd`;
        if ( $? ) {
            warn "rcoal failed on $thisname : $?, skipping\n";
            next;
        }

        my @tris = `grep "Actual coalesce n" ${thisname}_rcoal.out | awk '{ print \$4 }' | uniq`;
        grep chomp, @tris;
        my @ptris;
        for my $tri ( @tris ) {
            push @ptris, '0'x(5-length("$tri")) . $tri;
        }
        my @fos;

        for my $ptri ( @ptris ) {
            my $correctname = "${thisname}_$ptri";
            my $borkedname  = "${char26name}_$ptri";
            if ( $borkedname ne $correctname ) {
                die "expected file $borkedname does not exist\n" if !-e $borkedname;
                $cmd = "mv $borkedname $correctname";
                print "$cmd\n";
                print `$cmd`;
                die "error with $cmd : $?\n" if $?;
            }
            push @fos, "${thisname}_$ptri";
        }

        for my $f ( @fos ) {
            die "expected rcoal output file $f does not exist\n" if !-e $f;
        }
        print "triangles : " . join( ",", @tris );
        print "\n";
        print "ptriangles : " . join( ",", @ptris );
        print "\n";
        print "fos : " . join( ",", @fos );
        print "\n";

        for my $f ( @fos ) {
            ## bead model (from rcoal)
            my $fbm = "${f}_rcoal.bead_model";
            die "bead model $fbm already exists\n" if -e $fbm;
            $cmd = "$c3p2bmcmd $f > $fbm";
            print "$cmd\n";
            print `$cmd\n`;
            die "cmd error $?\n" if $?;
        }

        ## assemble for best
        my $count = scalar @tris;
        die "tris not same length as fos\n" if $count != scalar @fos;
        for ( my $i = 0; $i < $count; ++$i ) {
            my $tri = $tris[$i];
            my $f   = $fos[$i];
            if ( $tri <= $maxtriangles ) {

                $cmd = "$bestcmd -f $f -mw $mw -vc 2";
                # print "$cmd\n";
                $bestcmds{ $f } = $cmd;
                $besttriangles{ $f } = $tri;
            } else {
                warn "too many triangles, skipping $f\n";
            }
        }
        $fo = "$thisname.c3p";
    } else {
        $ptriangles = '0'x(5-length("$triangles")) . $triangles;
        $fo = "${thisname}_$ptriangles";
        print "$fo\n";
        `cp $thisname.c3p $fo`;
    }

    ## msdraw (only for msr output, doens't work with rcoal output)
    
    # create script for msdraw
    my $script = "molecule xyz
read_polyhedron $fo
xyz color=black
"
        ;
    open OUT, ">${thisname}_msdraw.script";
    print OUT $script;
    close OUT;

    $cmd = "$msdrawcmd -i ${thisname}_msdraw.script -p ${thisname}_msdraw.ps ps; ps2pdf ${thisname}_msdraw.ps";
    print "$cmd\n";
    print `$cmd`;

    ## bead model (from msroll)

    $cmd = "$c3p2bmcmd $fo > ${fo}_msr.bead_model";
    print "$cmd\n";
    print `$cmd\n`;
    die "cmd error $?\n" if $?;

    ## assemble for best

    if ( !$rcoal ) { # $rcoal assembles from rcoal output
        if ( $triangles <= $maxtriangles ) {

            $cmd = "$bestcmd -f $fo -mw $mw -vc 2";
            # print "$cmd\n";
            $bestcmds{ $fo } = $cmd;
            $besttriangles{ $fo } = $triangles;
        } else {
            warn "too many triangles, skipping $fo\n";
        }
    }

    if ( scalar keys %bestcmds > $maxmodels ) {
        print "stopping further models, exceeded maxmodels ($maxmodels)\n";
        last;
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

#print $cmds;
#die "testing\n";

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
print `$cmd`;

## ~/ultrascan3-somo-dev/us_somo/bin/us_saxs_cmds_t.app/Contents/MacOS/us_saxs_cmds_t json '{"bestcsv":1,"files":["L10_A_f0_95_000740vcm.be","L10_A_f0_9_000940vcm.be"],"triangles":[740,940],"name":"L10_A"}'
