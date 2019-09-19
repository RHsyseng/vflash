#! /bin/bash


## Functions
#
_usage() { 
    echo 
    echo "$( basename $0 ) [OPTIONS] command"
    echo "    where:"
    echo "      options:"
    echo "           -c file          Configuration file to use"
    echo "           -a action        Special predefined actions. Commands will not be run."
    echo "                              fresh      perform a fresh install of a sytem"
    echo "                              upgrade    upgrade the image on the vFlash device"
    echo "                              reinstall  reinstalls the system from the image "
    echo "                                           on the vFlash device"
    echo "           -i fqdn          IP address or FQDN of the iDRAC(s)"
    echo "                              Can be specified multiple times"
    echo "           -p               Prompt for the iDRAC password"
    echo "           -d               Enable debug output to file"
    echo "           -?               Display script usage"
    echo
    echo "      advanced options:"
    echo "           -l               list the available commands and thier help"
    echo "           -f function_dir  Directory containing functions (commands)"
    echo 
    echo "    Variables set in the configuration file will usually take precedence"
    echo "    over those set on the command line, with the following exceptions:"
    echo 
    echo "        iDRAC IP addresses specified on the command line"
    echo "        will append to the ones specified in the configuration file."
    echo 
    echo "        Commands specified on the command line will take precedence"
    echo "        over command specified in the configuration file."
    echo 
    echo "        If a command is specified on the command line, the commands specified in the"
    echo "        configuration file will not be executed."
    echo 
    echo "    Variables can also be exported to the script via the shell"
    echo 
    echo "    Commands:"
    echo "        Commands are specified in either the configuration file or"
    echo "        listed after all the options to the script."
    echo 
    echo "        It is suggested that the individual commands be enclosed"
    echo "        in either single or double quotes."
    echo 
    echo "        Commands will be executed sequentially as they are specified."
    echo 
    echo "        Most all commands require idrac_user and idrac_pass to be set."
    echo 
    echo "        Most will also require either the curl_cmd or ssh_cmd to be set."
    echo "            The curl_cmd and ssh_cmd commands are already defined and should"
    echo "            not need redefined in most cases"
    echo 
    echo "        Variables can be referenced using the percent % symbol. The %ip will"
    echo "            will reference the current iDRAC IP address."
    echo "            i.e. %idrac_pass will reference the $idrac_pass variable."
    echo 
    exit 1
}


## Parse the command line options
#
while getopts ':c:pdli:a:f:' OPTION
do
    case "${OPTION}" in
        c)
            [[ -f ${OPTARG} ]] \
                && source ${OPTARG} \
                || {
                    echo "${OPTARG} is not a file"
                    exit 1
                   }  
            ;;

        p)  
            getpass=true
            ;;

        d)
            enable_debug=true
            ;;

        l)
            list_commands=true
            ;;

        i)
            opt_ips+=(${OPTARG})
            ;;

        a)
            [[ ${OPTARG} == fresh || ${OPTARG} == update || ${OPTARG} == reinstall ]] \
                && action=${OPTARG}
            ;;

        f)
            fundir=${OPTARG}
            ;;

        ?)  _usage
            ;;
    esac
done

# Shift to easily present arguments
shift $(( $OPTIND - 1 ))

# Set the commands to process from the arguments
execute_commands=( "${execute_commands[@]}" "${@}")



##### Static Functions


## Read the remaining functions from the functions directory
#
: ${fundir:=functions}

for fun in ${fundir}/*
do
    source ${fun}
done





## Execute arguments here so we can control the order of execution
#  and make sure they overwrite any specified in the configuration file.
#

# List all the commands and thier functions
# Tell the _show_help function to convert underscores to dashes
DASHCMDS=true

[[ ${list_commands+x} == x ]] \
    && {
#        echo "Execute the following commands with the help option to see their usage"
#        echo "example:  $0 \"idrac-ntp-server-state help\""

        while read cmd
        do
#            echo ${cmd//-/_}
            ${cmd//-/_} help
        done < <( declare -F | sed -n -e '/-fx/!{s/^declare.* //p}' | sed -n -e '/^_/!p' )
    }


# Create a list of the iDRAC IPs to configure.
[[ ${opt_ips} ]] && idrac_ips=("${opt_ips[@]}")


# Get the password for the iDRAC user
[[ ${getpass} ]] \
    && { 
         read -s -p "Enter the password for the iDRAC: " idrac_pass
         echo
    }


# Enable debug logging to a file
[[ ${enable_debug} ]] \
    && {
        scriptname=${0##*/}
        scriptname=${scriptname%.*}

        : ${DEBUG:=${scriptname}-$(date +%j-%H%M%S).log}
    }



## Variables

## Set some defaults
default_idrac_user=root
default_idrac_pass=calvin
default_idrac_uid=2

default_vflash_iso_timeout=600
default_idrac_reset_timeout=300
default_job_wait_timeout=900

default_vflash_iso=http://localhost/pub/install.iso

default_vflash_partition=1
default_vflash_partition_name=BSTRAP

default_timezone=UTC


# Set values for needed variables
: ${idrac_user:=$default_idrac_user}
: ${idrac_pass:=$default_idrac_pass}
: ${idrac_uid:=$default_idrac_uid}

: ${timezone:=$default_timezone}

: ${vflash_iso_timeout:=$default_vflash_iso_timeout}
: ${idrac_reset_timeout:=$default_idrac_reset_timeout}
: ${job_wait_timeout:=$default_job_wait_timeout}

: ${vflash_iso:=$default_vflash_iso}
: ${vflash_partition:=$default_vflash_partition}
: ${vflash_partition_name:=$default_vflash_partition_name}

default_ssh_cmd="sshpass -e ssh -l ${idrac_user}"
default_curl_cmd="curl -k -u ${idrac_user}:${idrac_pass}"

: ${ssh_cmd:=$default_ssh_cmd}
: ${curl_cmd:=$default_curl_cmd}

# : ${redfish_url:=$default_redfish_url}


# Create an empty array to be used to pass to some functions.
empty_array=()




## Main
#

for ip in "${idrac_ips[@]}"
do
    echo "Executing commands on ${ip}"

    case "${action}" in
        fresh)
            echo "Performing a fresh installation"
            echo "-- Configuring the iDRAC"
            prepare_idrac ${ip}

#            echo "  -- Changing the iDRAC password"
#            [[ ${idrac_pass_new+x} != x ]] \
#                && {
#                    read -s -p "Enter the new password for the iDRAC: " idrac_pass_new
#                }
#            [[ $( idrac_password_set ${ip} ${idrac_uid} "${idrac_pass_new}" ) =~ success ]] \
#                && {
#                    echo "    - Password set"
#                    idrac_pass=idrac_pass_new
#                } || {
#                    echo "    - Failed setting password"
#                    exit 1
#                }

            echo "-- Configuring the vFlash partition"
            update_partition ${ip} ${vflash_partition} ${vflash_partition_name} ${vflash_iso}

            echo "-- Starting the installation of the system"
            install_system ${ip} ${vflash_partition} ${vflash_partition_name} ${vflash_iso}
            ;;

        update)
            echo "-- Updating the vFlash partition"
            update_partition ${ip} ${vflash_partition} ${vflash_partition_name} ${vflash_iso}
            ;;

        reinstall)
            echo "-- Reinstalling the system"
            install_system ${ip} ${vflash_partition} ${vflash_partition_name} ${vflash_iso}
            ;;

        *)
            for command in "${execute_commands[@]}"
            do
                ccmd=${command%% *}
                ccmd=${ccmd//-/_}

                carg=${command#* }
                carg=${carg//%/\$}
                echo "  -- Executing ${command}"
                echo "     As: $( eval echo ${ccmd} ${carg} )"

                eval ${ccmd} ${carg}
            done
            ;;
    esac
done

