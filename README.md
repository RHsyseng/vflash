# vflash

## Overview

This project provides functions and a script to configure and control the iDRAC9 and its vFlash SD card.
The functions try to return a known pass/fail or enable/disable state.

However, not all the commands used against the iDRAC produce states that can guarantee the latest status information returned is for the latest command executed.

Examples are `vflash_lastaction_status` and `vflash_partition_status`.

## Usage
The idrac-control.sh script takes both options and arguments. The options must be specified prior to the arguments. The arguments are essentially commands to the script.

### Options
```
-c file         Use file as a configuration file.
                    This option can be specified multiple times.
-i fqdn         Ip address or resolvable hostname of the iDRAC(s).
                    This option can be specified multiple times.
                    The script will loop through these ip addresses and 
                    execute the actions or commands on each.
-p              Prompt for the iDRAC password instead of using a variable.
-d              Enable debug output. It is highly recommended to always
                    use this option. All debug information is written 
                    to a file.
-a action       Special predefined actions. Arguments will not be processed.
                    fresh       Performs a fresh install of the system. This 
                                configures the boot information, vFlash
                                configuration, and performs a reboot to
                                install the system from the vFlash.
                                This action requires the following variables
                                be set: idrac_ips, vflash_partition,
                                vflash_partition_name, and vflash_iso.

                    update      Update the vFlash partition with a new image.
                                This action requires the following variables
                                be set: idrac_ips, vflash_partition,
                                vflash_partition_name, and vflash_iso.

                    reinstall   Reinstalls the system from an image on the
                                vFlash device.
                                This action requires the following variables
                                be set: idrac_ips, vflash_partition,
                                vflash_partition_name, and vflash_iso.
```

### Advanced options:
```
-l              List all the available commands and their usage.
-f dir          Directory that contains all the functions.
                        Defaults to ./functions.
```

### Arguments (Commands)
The arguments to the script are mostly function names and their parameters.
The arguments must be enclosed in quotes and are processed sequentially.
Most variables used within the script can be assigned as an argument as well.
However, the `idrac_ips` variable cannot be set this way.

Variables can be referenced by placing a percent (%) symbol immediately before the variable name.

For example:

    `idrac-control.sh "idrac_user=root" "idrac_pass=calvin" "vflash-partition-status %ip 1"`

The above will execute 3 commands, first it will set the `idrac_user` variable, then the `idrac_pass` variable.
Finally, it will execute the `vflash-partition-status` command.
This command takes two arguments, the ip address of the iDRAC and the vFlash partition number.

By specifying, a percent in front of the `ip` variable, the system will substitute the ip address of the system currently being configured when calling the command.



## Variables
This script relies heavily on variables.
Variables are used to hold the argument commands, ip addresses, iDRAC credentials, and most everything else including the racadm command to execute.
Most variables can be defined in multiple ways.

In a configuration file:

```
example.cfg:
    idrac_user=root

# idrac-control.sh -c example.cfg
```

Exported to the shell:
```
# export idrac_user=root
# idrac-control.sh
```

Set when executing the script:
```
# idrac_user=root idrac-control.sh
```

As a command to the script:
```
# idrac-control.sh "idrac_user=root"
```


### Precedence
- Variables set as a command will usually take precendence over setting the variables in any other way.
- Variables set in the configuration file usually take precedence over those set on the command line.

The following are exceptions:

- The ip addresses specified using the -i option on the command line will append to any specified in the configuration file.
- If a command is specified on the command line, no commands in the configuration file will be executed.






## Configuration Files
The configuration file is sourced into the script using the bash source command.
This enables setting the variables needed to run the script inside the configuration file.
This also means that you can include bash commands in the configuration file and dynamically create variables if desired.

The `-c` option can be specified multiple times and the configuration files are source sequentially. This means if a variable is defined in multiple files, the last specification of the variable will overwrite the previous specifications.

The `example.cfg` file lists most variables that can be changed.
There are two that warrant more attention.

- `idrac_ips`
This variable is a bash array by default.
It can be defined as a space seperated string if desired.
The array contains a list of iDRAC ip addresses or resolvable names.
If this variable is defined in the configuration file, any ip addresses specified using the -i option will be appended to the ones defined.

- `execute_commands`
 This variable is a bash array and must be defined as one.
Any command specified here will be executed sequentially.


By creating multiple configuration files, custom actions can be created.
For example, using two configuration files as follows:

idrac.cfg
```
idrac_user=root
idrac_pass=calvin
idrac_ips=( 
    "172.22.0.231"
    "172.22.0.232"
    "172.22.0.233"
)
```

commands.cfg
```
vflash_partition=1
vflash_partition_name=BSTRAP
vflash_iso=http://localhost/image.iso

execute_commands=(
    "vflash-update_partition-update %ip %vflash_partition %vflash_partition_name %vflash_iso}"
    "vflash-partition-status %ip 1"
)
```


The script could be executed by calling the `-c` option twice.
This will cause the script to source both configuration files and have the execute commands run on the host specified in the idrac.cfg file.
`idrac-control.sh -c idrac.cfg -c commands.cfg`



## Debug
The system will write debug output to a file if the `DEBUG` variable is set.
This variable should be set to the name of the file to write the data to.
By setting this variable, there is no need to specify the `-d` option on the command line.
The `-d` option just sets the variable to the program name followed by the julian date and time.



## Expanding the scripts functionality
The script was written to allow it to be easily expanded.
All the commands available in the script are just the function names.

The commands to the script can be specified using dashes or underscores.
The script presents the function names as commands and changes the underscores to dashes when displaying the help.
The script will automatically convert dashes to underscores in the function name.
For example, `vflash-partition-status` and `vflash_partition_status` are the same command and either can be specified on the command line.

The functionality of the script can be expanded simply by creating new functions. The functions should follow a few guidelines as follows:

- All variables whose values change should be declared as local variables.

- The function should not print anything except the string it is returning to the screen.
  - All normal output should be captured into arrays.
  - One array can be used for both stdout and stderr or two arrays can be used to differentiate stdout and stderr.

- The function should call the `_show_help` function if its first argument is 'help'.

- The function should call the `debug_print` function before it exits.

- Functions can be hidden from the user when the `-l` option is specified by naming the function with an underscore as the first character.
This is useful for helper functions that should not be called directly by a user.



### Function help
All functions that are not hidden from the user should take 'help' as a possible first argument.

There is a function called _show_help. This is a hidden function and is used to present the help information on all functions.
The _show_help function should be called if the first argument to the function is 'help'.
All user visible functions should define the following local variables and then call the _show_help function if requested.
    local DESCRIPTION="A short description of what this function does"
    local OPTIONS="The usage options for this function"
    local RETURNS="What does this function return if anything"
The RETURNS variable is optional if the function does not return anything.

### Function debug output
All functions should call the debug_print function to write output to the debug log.
The debug_print functions takes up to three arguments.
The first argument is the name of an array that contains the stdout from any commands executed.
The second argument should be the string that is returned by the function.
    If nothing is returned by the function, any useful string of data can be specified.
The third argument is the name of an array that contains the stderr from any commands executed.

Note: The first and third arguments must be array names and not data. The function takes these names as references.






