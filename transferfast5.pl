use strict;
use Data::Dumper;
use Getopt::Long;
use POSIX qw(strftime);

################################################################################
#
# MIT License
# Copyright (C) Chee-Hong WONG
#
# perl transferfast5.pl check --experiments run-2016-08-24.txt
# perl transferfast5.pl run --experiments run-2016-08-24.txt
#
#
# read and check configuration file
# loop:
#   find new .fast5 file
#   generate the transfer file list
#   rsync the file and remove the source if successful
#
################################################################################
my $G_USAGE = "
$0 <command> --experiments <run_configuration_file>

<command> [check, run]
          check : report the run configuration setting
          run   : perform the transfer as per configuration file

<run_configuration_file>
          The run configuration file is a tab separated text file.
          A line that begins with '#' is considered a comment line.
          Each line contains 3 columns as follow:
            Col 1 : sample id / experiment id
            Col 2 : MinION id
            Col 3 : Destination
";

my $G_BREAK_INTERVAL = 60; # unit=seconds; rest time between transfer attempt

my $command = undef;
if (!defined $ARGV[0] || substr($ARGV[0],0,2) eq '--') {
    die("Please specify the command.\n",$G_USAGE);
}
$command = shift @ARGV;

my $exptfile = undef;
my $logfile = undef;
GetOptions (
"experiments=s" => \$exptfile
) or die($G_USAGE);

if (!defined $exptfile || ! -f $exptfile) {
	die("Please specify the run configuration file.\n", $G_USAGE);
}

my $logfile = $exptfile.'.log';
open LOGFILE, ">>$logfile" || die "Fail to open $logfile\n$!\n";

my @experiments = ();
checkExperimentFile ($exptfile, \@experiments);
if ('check' eq $command) {
    foreach my $exptRef (@experiments) {
        my $msg = $exptRef->{minion}.' ('.$exptRef->{experiemnt}.') --> '.$exptRef->{destination};
        print LOGFILE "INFO: " .$msg. "\n";
        print STDERR "INFO: " .$msg. "\n";
    }
}

if (scalar(@experiments)>0 && 'run' eq $command) {
    transferExperimentFile (\@experiments);
}

close LOGFILE;

exit 0;

sub checkExperimentFile {
    my ($file, $exptsRef) = @_;
    @{$exptsRef} = ();
    
    my $toBait = 0;
    open INFILE, $file || die "Fail to open $file\n$!\n";
    my %experiments = ();
    my %minions = ();
    my %destinations = ();
    while (<INFILE>) {
        next if (/^#/);
        chomp();
        my @bits = split(/\t/, $_);
        
        my $toAdd = 1;
        if (exists $experiments{$bits[0]}) {
            my $msg = 'Line#'.$..': Experiment of "'.$_.'" already seen in line '.$experiments{$bits[0]};
            print LOGFILE "WARNING: " .$msg. "\n";
            print STDERR "WARNING: " .$msg. "\n";
            # same experiment using >1 minion?
            #$toAdd = 0;
        }
        if (exists $minions{$bits[1]}) {
            my $msg = 'Line#'.$..': Destination of "'.$_.'" already seen in line '.$minions{$bits[1]};
            print LOGFILE "ERROR: " .$msg. "\n";
            print STDERR "ERROR: " .$msg. "\n";
            # TODO: possibly two experiment in an experiment?
            $toAdd = 0;
        }
        if (exists $destinations{$bits[2]}) {
            my $msg = 'Line#'.$..': Destination of "'.$_.'" already seen in line '.$destinations{$bits[2]};
            print LOGFILE "WARNING: " .$msg. "\n";
            print STDERR "WARNING: " .$msg. "\n";
            # same experiment using >1 minion?
            #$toAdd = 0;
        }
        
        if (0==$toAdd) {
            $toBait = 1;
        } else {
            $experiments{$bits[0]} = $.;
            $minions{$bits[1]} = $.;
            $destinations{$bits[2]} = $.;
            push @{$exptsRef}, {experiemnt=>$bits[0], minion=>$bits[1], destination=>$bits[2]};
        }
    }
    close INFILE;
}

sub countNumberOfFiles {
    my ($file, $rowsRef) = @_;
    
    my %counters = ();
    my %fofn = ();
    open INFILE, $file || die "Fail to open $file\n$!\n";
    while (<INFILE>) {
        chomp();
        next if ($_ eq 'File not found');
        
        my @bits = split(/\_/, $_);
        # locate the minion and increase the counter
        foreach my $bit (@bits) {
            if ($bit =~ /MN\d\d\d\d\d/) {
                $counters{$bit}++;
                
                $fofn{$bit} = [] if (!exists $fofn{$bit});
                push @{$fofn{$bit}}, $_;
                last;
            }
        }
        
    }
    close INFILE;
    
    # let's update the return values
    my $total = 0;
    foreach my $rowRef (@{$rowsRef}) {
        $rowRef->{chunkTotal} = 0;
        my $minion = $rowRef->{minion};
        if (exists $counters{$minion}) {
            my $count = $counters{$minion};
            $total += $count;
            $rowRef->{chunkTotal} = $count;
            $rowRef->{total} = 0 if (!exists $rowRef->{total});
            $rowRef->{total} += $count;
            
            #$exptRef->{minionfofn}
            open OUTFILE, '>'.$rowRef->{minionfofn} || die "Fail to open ".$rowRef->{minionfofn}."\n$!\n";
            print OUTFILE join("\n", @{$fofn{$minion}}), "\n";
            close OUTFILE;
        } else {
            # there is not file for this minion
        }
    }
    
    return $total;
}

sub transferExperimentFile {
    my ($exptsRef) = @_;

    my $timeStamp = strftime "%Y-%m-%d_%H:%M:%S", localtime;
    my $processId = $$;
    my $msg = '# '.$timeStamp.' Transfer process#'.$processId.' started with following configuration..';
    print LOGFILE "INFO: " .$msg. "\n";
    print STDERR "INFO: " .$msg. "\n";
    
    @{$exptsRef} = sort {$a->{experiment} <=> $b->{experiment}} @{$exptsRef};
    foreach my $exptRef (@{$exptsRef}) {
        $msg = $exptRef->{minion}.' ('.$exptRef->{experiemnt}.') --> '.$exptRef->{destination};
        print LOGFILE "INFO: " .$msg. "\n";
        print STDERR "INFO: " .$msg. "\n";
    }
    
    foreach my $exptRef (@{$exptsRef}) {
        my $minionfofn = 'fofn.'.$processId.'.'.$exptRef->{minion}.'.lst';
        $exptRef->{minionfofn} = $minionfofn;
    }

    my $grandTotal = 0;
    my $stime = undef; my $etime = undef;
    while (0==0) {
        $timeStamp = strftime "%Y-%m-%d_%H:%M:%S", localtime;
        
        #find . -type f -name "*.fast5" > fofn.lst
        #grep '_<minionid>_' fofn.lst > fofn.<minionid>.lst
        #rsync -avLzh --remove-source-files --files-from=fofn.<minionid>.lst . <destination>
        
        my $fofn = 'fofn.'.$processId.'.lst';
        my @args = ();
        if ( $^O =~ /mswin/i) {
            @args = ('dir','*.fast5','/B', '>',$fofn, '2>&1');
        } else {
            @args = ('find','.','-type','f','-name','"*.fast5"','>',$fofn);
        }
        my $syscommand = join(' ', @args);
        $stime = time;
        my $syscommandExit = system($syscommand);
        if (0==$syscommandExit) {
            $etime = time;
            
            my $total = countNumberOfFiles($fofn, $exptsRef);
            $grandTotal += $total;
            $msg = '# '.$timeStamp.' Detected '.$total.' .fast5 in '.($etime-$stime).' sec.. cummulatively: '.$grandTotal.' .fast5';
            print LOGFILE "INFO: " .$msg. "\n";
            print STDERR "INFO: " .$msg. "\n";
            
            foreach my $exptRef (@{$exptsRef}) {
                # let's generate the transfer list for each minion
                if ($exptRef->{chunkTotal}>0) {
                    # let's transfer for each minion
                    @args = ('rsync','-qavLzh','--remove-source-files','--files-from='.$exptRef->{minionfofn},'.',$exptRef->{destination});
                    $syscommand = join(' ', @args);
                    print $syscommand, "\n";
                    $stime = time;
                    #system(@args) == 0 || die "system @args failed: $?";
                    system($syscommand) == 0 || die "system @args failed: $?";
                    $etime = time;
                } else {
                    $etime = $stime = time;
                }
                
				$msg = 'Last transfer '.$exptRef->{chunkTotal}.' .fast5 in '.($etime-$stime).'s, cummulatively '.((exists $exptRef->{total} && '' ne $exptRef->{total}) ? $exptRef->{total} : 0).' .fast5, '.$exptRef->{minion}.' --> '.$exptRef->{destination};
                print LOGFILE "INFO: " .$msg. "\n";
                print STDERR "INFO: " .$msg. "\n";
            }
            
            print STDERR "\n";
            
        } elsif (256==$syscommandExit) {
            $etime = time;
            
            $msg = '# '.$timeStamp." @args failed: $?\n";
            print LOGFILE "INFO: " .$msg. "\n";
            print STDERR "INFO: " .$msg. "\n";
            
            print STDERR "\n";
            
        } else {
            die "system @args failed: $?";
        }

        sleep($G_BREAK_INTERVAL);
    }
}

