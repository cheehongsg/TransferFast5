# TransferFast5

TransferFast5 is a perl program that transfers .fast5 files from the computer acquiring data with MinION(s) to alternative location(s).

## How does TransferFast5 work?

A run configuration file (tab-separated file) is set up with the association of a sample id, the corresponding MinION id responsible for data acquisition and the .fast5 archival destination location. If your computer works with multiple MinIONs in parallel, each MinION will have to have its own row of association in this file.

.fast5 files present within the current directory (this should be the MinKNOW's data/reads directory) are "copied" to the destination location based on the run configuration file settings. Once the files are copied successfuly, they are removed from the MinKNOW's data directory. (This is implemented with rsync with "--remove-source-files” options.) The program then waits for 60 seconds before repeating this process.

Once your run(s) have completed (pressing "Stop Acquisition" button in MinKNOW software), you may terminate the perl program by pressing <CTRL+C> when all files have been transferred. TransferFast5 will report the number of files transferred in the last attempt. It is safe to stop TransferFast5 when this number is zero for transfer attempt(s) after stopping your runs.


## WARNING

The rsync "--remove-source-files” option may seem like a dangerous option. I have absolute faith in rsync which is one of the oldest software. But you have to assess your risk appetite.

Each transfer attempt starts with TransferFast5 saving the list of .fast5 files in the current directory to the file "fofn.<TransferFast5_process_id>.lst". TransferFast5 then splits them into individual file ("fofn.<TransferFast5_process_id>.<MinION_id>.lst") based on the MinION id present in the filename. The individual file ("fofn.<TransferFast5_process_id>.<MinION_id>.lst") is specified with rsync "--files-from=" option. This allows more effective I/O in multiple parallel (MinION) runs scenario and transfer metric tracking. The rsync "--remove-source-files” option is absolute critical in reducing the I/O load on the next transfer attempt.   


## Alternatives

Too much hassles? [Nanopore_rsync](https://github.com/paulranum11/Nanopore_rsync) may be the tool for your task.

## Installation

### Software Pre-requisites

1. <b>Perl</b> .. to run the script transferfast5.pl

|     | Mac | Ubuntu | Windows |
| --- | --- | --- | --- |
| Availability | Included by platform. | Included by platform. | NOT included by platform. |
| Download | [perl.org](https://www.perl.org/) | [perl.org](https://www.perl.org/) | [perl.org](https://www.perl.org/) |

2. <b>rsync</b> .. to perform the copying/transfer

|     | Mac | Ubuntu | Windows |
| --- | --- | --- | --- |
| Availability | Likely outdated. | Included by platform. | NOT included by platform. |
| Download | See "Updating Mac rsync" below. | n.a. | [cwRsync](https://www.itefix.net/content/cwrsync-free-edition) |

#### Updating Mac rsync
It is easier to update the rsync via the [HomeBrew](https://brew.sh/) framework.

To do so, open a Terminal. (<Command+Space>, type "Terminal" and press \<enter>.)

```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

Paste the above in the Terminal prompt to install HomeBrew.

```
brew install rsync
```

Paste the above in the Terminal prompt to install [Rsync](http://brewformulas.org/Rsync).

If you prefer to build your own executable, please visit [rsync homepage](https://rsync.samba.org/) for build instruction.

## Run Configuration File

The run configuration file is a tab separated text file.

A line that begins with '#' is considered a comment line.

Each line contains 3 columns as follow:

| Column | Description | Examples |
|:---:| --- | --- |
| 1 | sample id /<br>experiment id | WTDR009 |
| 2 | MinION id | MN18270 |
| 3 | destination | remoteServer:/ONT-datastore/2016-08-24-R9-WTD-R009/reads/<br>/Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads |

## 'Live' Transferring Usage Scenarios

Assume that you have downloaded transferfast5.pl to your home directory.

**IMPORTANT**: For TransferFast5 to work, your account must have read, write and execute permission on MinKNOW's data/reads directory. Read permission is needed to get the content for transfer. Write and execute permission are needed for rsync "--remove-source-files” option to remove successfully transferred files.

### Single MinION Run to a USB portable disk

Let's assume that we connected MinION MN18270 to a Mac to sequence the sample WTDR009 and will like to have all .fast5 files transfer to the USB disk named "ONT-BKUP" in the folder "2016-08-24-R9-WTD-R009/reads".

Create a run configuration file (says ~/run-2016-08-24.txt) with its content as follow:

```
# experiment	minion_id	destination
WTDR009	MN18270	/Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
```

Open a terminal window and enter the following commands.

Create the destination directory.

```
mkdir -p /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
```

Change directory to MinKNOW's data/reads directory.


```
cd /Library/MinKNOW/data/reads  # for Mac
```

To check your run configuration:


```
perl ~/transferfast5.pl check --experiments run-2016-08-24.txt
```

You should see the output:

```
INFO: MN18270 (WTDR009) --> /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
```

To initiate the transfer (either before or after you start your MinION acquisition via MinKNOW):


```
perl transferfast5.pl run --experiments run-2016-08-24.txt
```

Transfer metrics will be reported in the Terminal window and logged in the log file "<run_configuration_file>.log" (run-2016-08-24.txt.log in this case). For instance:

```
INFO: # 2016-08-24_16:10:08 Transfer process#54221 started with following configuration..
INFO: MN18270 (WTDR009) --> /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
INFO: # 2016-08-24_16:10:08 Detected 1 .fast5 in 0 sec.. cummulatively: 1 .fast5
INFO: Last transfer 1 .fast5 in 1s, cummulatively 1 .fast5, MN18270 --> /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
INFO: # 2016-08-24_16:11:09 Detected 1 .fast5 in 0 sec.. cummulatively: 2 .fast5
INFO: Last transfer 1 .fast5 in 0s, cummulatively 2 .fast5, MN18270 --> /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
INFO: # 2016-08-24_16:12:10 Detected 0 .fast5 in 0 sec.. cummulatively: 2 .fast5
INFO: Last transfer 0 .fast5 in 0s, cummulatively 2 .fast5, MN18270 --> /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/
```

### Single MinION Run to a remote server

Now, instead of transferring to a USB disk, we wish to transfer .fast5 files acquired by MinION MN18270 for sample WTDR009 to a remote storage server "storageServer.org" in the folder "/ONT-datastore/2016-08-24-R9-WTD-R010/reads/".

The only change to the run configuration file above (~/run-2016-08-24.txt) is the 3rd column destination:

```
# experiment	minion_id	destination
WTDR009	MN18270	storageServer.org:/ONT-datastore/2016-08-24-R9-WTD-R009/reads/
```

#### Password-less SSH login

It is common to be prompted for your password when rsync'ing to a remote server. TransferFast5 assumes that you have already set up a password-less SSH login or SSH Key-based login to the remote server. See [How can I set up password-less SSH login?](https://askubuntu.com/questions/46930/how-can-i-set-up-password-less-ssh-login) to set up one. 

Open a terminal window and create the destination directory on the remote storage server.

```
ssh storageServer.org
# enter your password to login to your remote storage server
mkdir -p /ONT-datastore/2016-08-24-R9-WTD-R009/reads/
exit
```

The rest of the commands to be entered in the Terminal window is exactly the same as the scenario of transferring to a USB disk. Commands repeated here for completeness.

```
cd /Library/MinKNOW/data/reads  # for Mac

perl ~/transferfast5.pl check --experiments run-2016-08-24.txt
# check your output
# INFO: MN18270 (WTDR009) --> /Volumes/ONT-BKUP/2016-08-24-R9-WTD-R009/reads/

# You may start your MinION acquisition via MinKNOW either before or after you initate the transfer
perl transferfast5.pl run --experiments run-2016-08-24.txt
```

### Multiple MinIONs run transfer

We routinely run multiple MinIONs connected to a single MacBook Pro.

The run configuration file (~/run-2016-11-02.txt) for parallel data acquisition of sample WTDR014 with MinION MN18151 and sample WTDR015 with MinION MN19600 to be transferred to our remote storage server "storageServer.org" is as follow:

```
# experiment	minion_id	destination
WTDR014	MN18151	storageServer.org:/ONT-datastore/2016-11-02-R9.4-WTD-R014/reads/
WTDR015	MN19600	storageServer.org:/ONT-datastore/2016-11-02-R9.4-WTD-R015/reads/
```

Open a terminal window and create the destination directory on the remote storage server.

```
ssh storageServer.org
# enter your password to login to your remote storage server
mkdir -p /ONT-datastore/2016-11-02-R9.4-WTD-R014/reads/
mkdir -p /ONT-datastore/2016-11-02-R9.4-WTD-R015/reads/
exit
```

The rest of the commands to be entered in the Terminal window is exactly the same as the scenarios above except for the run configuration filename. Commands repeated here for completeness.

```
cd /Library/MinKNOW/data/reads  # for Mac

perl ~/transferfast5.pl check --experiments run-2016-11-02.txt
# check your output
# INFO: MN18151 (WTDR014) --> storageServer.org:/ONT-datastore/2016-11-02-R9.4-WTD-R014/reads/
# INFO: MN19600 (WTDR015) --> storageServer.org:/ONT-datastore/2016-11-02-R9.4-WTD-R015/reads/

# You may start your MinION acquisition via MinKNOW either before or after you initate the transfer
perl transferfast5.pl run --experiments run-2016-11-02.txt
```
