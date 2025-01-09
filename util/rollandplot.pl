#!/usr/bin/perl

$notes = "
usage: $0 filename

runs msroll on filename
accepts .xyzr or .pdb
then runs msdraw to produce basename.pdf

";

$f = shift || die $notes;

die "$f does not exist\n" if !-e $f;

$xyzr = $f =~ /\.xyzr$/i;
$pdb = $f =~ /\.pdb$/i;

die "$f is not .xyzr or .pdb\n" if !$xyzr && !$pdb;

print "ok\n";

$fine = shift || 0.25;

$msrext = "_xyzr" if $xyzr;

$bname = $f;
$bname =~ s/\.(pdb|xyzr)$//i;
$sname = $bname;
$sname =~ s/[_-]//g;
    
$script = "molecule $sname 
read_polyhedron $bname.c3p
$sname color=black
";

open OUT, ">$bname.script";
print OUT $script;
close OUT;

$script = "molecule $sname 
read_polyhedron $bname
$sname color=black
";

open OUT, ">${bname}_rcoal.script";
print OUT $script;
close OUT;

$cmd = "/Users/eb/besttest/msroll/bin/msroll$msrext -m $f -f $fine -t $bname.c3p -v $bname.c3v -p 0.0
/Users/eb/besttest/msroll/bin/msdraw -i $bname.script -p $bname.ps ps
ps2pdf $bname.ps
echo open $bname.pdf
";

print "$cmd\n";
print `$cmd`;
