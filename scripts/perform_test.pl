#!/usr/bin/perl
#*******************************************************************************
#
# This script runs all the tests in a test directory. The tests are contained
# in their own directory, and any bad tests are copied back there for later
# comparison. -- dylan
#
# All command line arguments are compulsory - run the script without them to get
# the usage message.
#
# (c) Daniel Grimwood, University of Western Australia, 2004.
# (c) Dylan Jayatilaka, 2006
#
# $Id: perform_tests.pl 3975 2013-05-16 16:51:17Z dylan_ $
#
#*******************************************************************************

use strict;
use English;
use File::Copy ('copy');

my $testdir = "";
my $testjob = "";
my $program = "";
my $cmp     = "perl -w ./scripts/compare_output.pl";

my $passed = 1;

# Analyse command line
&analyse_arguments(@ARGV);

# Open the test suite directory
opendir(TESTDIR,$testdir) || die "cannot open directory $testdir";
closedir(TESTDIR);

# Banner
print "\n";
print "Using the program         ... $program\n";
print "Running test in directory ... $testdir\n";
print "Running test job          ... $testjob\n";

# Main loop over test jobs

   # Set stdin and stdout
   my $input  = "";
   my @input  = ( "stdin"  );
   my $output = "";
   my @output = ( "stdout" );
   my $delete = "";
   my @delete = ( );

   # Read extra input and output files from IO file.
   # Read files to delete at end of job
   if (open(TEST,"< $testdir/$testjob/IO")) {
      while (<TEST>) {
        if (m/input\s*:\s+(\S+)/)  { push (@input, $1); }
        if (m/output\s*:\s+(\S+)/) { push (@output,$1); }
        if (m/delete\s*:\s+(\S+)/) { push (@delete,$1); }
      }
   }

   # Copy the input files to the current directory.
   foreach $input (@input) {
     copy("$testdir/$testjob/$input",$input);
   }

   # Run the program on the test job
   my $status = "";

   if (system($program) != 0) {

      # CRASH ....
      $status = "PROGRAM CRASHED";
      $passed = 0;

      # Loop over output files for comparison
      foreach my $output (@output) {

         # cmp returns 0 if they are equal
         # So $ok is 1 (true) if they are equal
         my ($ok,$ref);
         $ref = &escape("$testdir/$testjob/$output");
         $ok = -e $output && ! system("$cmp $ref $output");

         # Copy failed output files back
         if (! $ok) {
            copy($output, $ref . ".bad" );
         }

      }

   } else {

      # PASS ....
      $passed = 1;

      # Loop over output files for comparison
      foreach my $output (@output) {

         # cmp returns 0 if they are equal
         # So $ok is 1 (true) if they are equal
         my ($ok,$ref);
         $ref = &escape("$testdir/$testjob/$output");
         $ok = -e $output && ! system("$cmp $ref $output");

         # Copy failed output files back
         if (! $ok) {
            copy($output,"$testdir/$testjob/$output".".bad");
         }

         # Has it passed?
         $passed = $passed && $ok;

      }

      # Has job passed?
      if ($passed) {
        $status = "passed";
      } else {
        $status = "FAILED";
      }

   }

print "Status                    ... $status\n";

my $exit_code = ($passed == 1) ? 0 : 1;
exit($exit_code);

#*******************************************************************************
sub analyse_arguments {
# Analyse the command line arguments
   my ($arg,$argerr);
   $argerr=0;
   my @args = @_;
   $argerr=1 if (@args==0);

   # Extract the command line arguments
   while (@_) {
     $arg = shift;
     $_ = $arg;
     if (/^-/) {
       /^-testdir\b/          && do { $testdir      = shift; next; };
       /^-testjob\b/          && do { $testjob      = shift; next; };
       /^-program\b/          && do { $program      = shift; next; };
       /^-cmp\b/              && do { $cmp          = shift; next; };
       warn "\n Error : unexpected argument $arg\n";
       $argerr=1;
     }
   }

   if ($testdir eq "") {
     warn " Error : -testdir option is empty string";
     $argerr = 1;
   } elsif (! -d $testdir) {
     warn " Error : \"$testdir\" is not a directory";
     $argerr = 1;
   }

   if ($program eq "") {
     warn " Error : -program option is empty string";
     $argerr = 1;
   }

   if ($cmp eq "") {
     warn " Error : -cmp option is empty string";
     $argerr = 1;
   }

   if ($argerr) {
     print << 'EOF';

 Usage:
    perl -w perform_tests.pl -testdir dir -program prog -cmp cmp

 Where:

    -testdir dir   means run test job in directory "dir".

    -testjob job   means run test job with stdin input file in "dir/job".

    -program prog  "prog" is the program to test e.g. INTEL-ifort-on-LINUX/run_molecule.exe
                   It should read in the real file "stdin", and output to file "stdout".

    -cmp     cmp   "cmp" is the comparison program for stdout files e.g.
                   "perl -w scripts/compare_stdout.pl"

EOF
   exit (1);
   }
}

#*******************************************************************************
sub escape {
# Escape bash arguent
   my $arg = shift;
   $arg =~ s/([^a-zA-Z0-9])/\\$1/g;
   return $arg;
}
