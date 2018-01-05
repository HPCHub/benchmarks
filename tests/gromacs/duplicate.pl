#!/usr/bin/perl

=head1 Generate duplicated pdb

Background idea - take original pdb, calculate bounding box, copy-paste in given direction.

=cut

if (not(defined($ARGV[0] ))) {
   print "Usage: 
duplicate.pl file.pdb [xyz]
";
   exit(1);
};

open(FD,"<".$ARGV[0]) or die "Can't open file ".$ARGV[0];
@lines=<FD>;
close(FD);

@orig_chains = (); 
@orig_ssbonds=();
@orig_cons=();
%orig_atoms = ();

@orig_ranges=();
$range_id=0;

%type_range=();

$re_f='-?\d+\.?\d*';
$bbox{X}{min} = undef;
$bbox{X}{max} = undef;
$bbox{Y}{min} = undef;
$bbox{Y}{max} = undef;
$bbox{Z}{min} = undef;
$bbox{Z}{max} = undef;
sub bbox_put($$$) {
  my ($B,$axe,$v) = @_;
  if(defined($B->{$axe}{min})) {
     if($v<$B->{$axe}{min}) {
        $B->{$axe}{min}=$v;
     };
     if($v>$B->{$axe}{max}) {
        $B->{$axe}{max}=$v;
     };
  } else {
     $B->{$axe}{min}=$v;
     $B->{$axe}{max}=$v;
  };
};
foreach $line (@lines) {
   $local=0;
   if(/^COMPND\s+3 CHAIN: (.*);/) {
       push @orig_chains, $1
       $local=1;
       $type_range{'COMPND'}=$range_id;
   };

#       ATOM      1      N      LYS      A       1      35.365  22.342 -11.980  1.00 22.28           N  
   if(/^(HETATM|ATOM)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+($re_f)\s+($re_f)\s+($re_f)\s+($re_f)\s+($re_f)\s+(\S+)/) {
       push @{ $orig_atoms{$4} } , {
          'Variant' => $1,
          'Number' => $2,
          'Kind' => $3,
          'Part' => $4,
          'Chain' => $5,
          'Rsd' => $6,
          'X' => $7,
          'Y' => $8,
          'Z' => $9,
          'P' => $10,
          'R' => $11,
          'Type' => $12
        };
        $type_range{$1}=$range_id;
        bbox_put(\%bbox,'X',$7);
        bbox_put(\%bbox,'Y',$8);
        bbox_put(\%bbox,'Z',$9); 
       $local=1;
   };
#SSBOND   1 CYS A    6    CYS A  127                          1555   1555  1.97  
   if(/^SSBOND\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+($re_f)/) {
      push @orig_ssbonds, {
          'Number' => $1,
          'Part1' => $2,
          'Chain1' => $3,
          'Rsd1' => $4,
          'Part2' => $5,
          'Chain2' => $6,
          'Rsd2' => $7,
          'Sym1' => $8,
          'Sym2' => $9,
          'Value' => $10 
      };
      $type_range{SSBOND}=$range_id;
      $local=1;
   };
   if(/^CONECT\s+(\d+)\s+(\d+)/) {
      push @orig_cons, {
          'Atom1' => $1,
          'Atom2' => $2
      };
      $type_range{CONECT}=$range_id;
      $local=1;
   };
   
   if($local == 0) {
     $orig_ranges[$range_id].=$_;
   } else {
     if(defined($orig_ranges[$range_id])) {
       $range_id++;
     };
   };
};

########



for ($range_id=0;$range_id<=$#orig_ranges;$range_id++) {
   for $type (keys(%type_range)) {
      if($type_range{$type} == $range_id) {
          
      };
   };
};
