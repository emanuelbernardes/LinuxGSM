#!/bin/bash
# LGSM command_mods_install.sh function
# Author: Daniel Gibbs
# Contributor: UltimateByte
# Website: https://gameservermanagers.com
# Description: Core functions for mods list/install/update/remove

local commandname="MODS"
local commandaction="Core functions for mods"
local function_selfname="$(basename $(readlink -f "${BASH_SOURCE[0]}"))"

## Useful variables
# Files and Directories
modstmpdir="${tmpdir}/mods"
extractdir="${modstmpdir}/extracted"
modsdatadir="${lgsmdir}/data/mods"
modslockfile="installed-mods-listing"
modslockfilefullpath="${modsdatadir}/${modslockfile}"

# Create mods directory if it doesn't exist
# Assuming the game is already installed as mods_list.sh checked for it.
fn_mods_dir(){
	if [ ! -d "${modinstalldir}" ]; then
		fn_script_log_info "Creating mods directory: ${modinstalldir}"
		fn_print_dots "Creating mods directory"
		sleep 1
		mkdir -p "${modinstalldir}"
		fn_print_ok_nl "Created mods directory"
	fi
}

# Clear mod download directory so that there is only one file in it since we don't the file name and extention
fn_clear_tmp_mods(){
	if [ -d "${modstmpdir}" ]; then
		rm -r "${modstmpdir}"
		fn_script_log "Clearing temp mod download directory: ${modstmpdir}"
	fi
	# Clear temp file list as well
	if [ -f "${modsdatadir}/.removedfiles.tmp" ]; then
		rm "${modsdatadir}/.removedfiles.tmp"
	fi
}

# Create tmp download mod directory
fn_mods_tmpdir(){
	if [ ! -d "${modstmpdir}" ]; then
			mkdir -p "${modstmpdir}"
			fn_script_log "Creating temp mod download directory: ${modstmpdir}"
	fi
}

fn_mod_dl(){
	# fn_fetch_file "${fileurl}" "${filedir}" "${filename}" "${executecmd}" "${run}" "${force}" "${md5}"
	fileurl="${modurl}"
	filedir="${modstmpdir}"
	filename="${modfilename}" 
	fn_script_log "Downloading mods to ${modstmpdir}"
	fn_fetch_file "${fileurl}" "${filedir}" "${filename}"
	# Check if variable is valid checking if file has been downloaded and exists
	if [ ! -f "${modstmpdir}/${modfilename}" ]; then
		fn_print_fail "An issue occurred upon downloading ${modprettyname}"
		core_exit.sh
	fi
}

fn_mod_extract(){
	# fn_dl_extract "${filedir}" "${filename}" "${extractdir}"
	filename="${modfilename}"
	if [ ! -d "${extractdir}" ]; then
		mkdir -p "${extractdir}"
	fi
	fn_script_log "Extracting ${modprettyname} to ${extractdir}"
	fn_dl_extract "${filedir}" "${filename}" "${extractdir}"
}

fn_mod_lowercase(){
	# Converting files to lowercase
	if [ "${modlowercase}" == "LowercaseOn" ]; then
		fn_print_dots_nl "Converting ${modprettyname} files to lowercase"
		fn_script_log "Converting ${modprettyname} files to lowercase"
		find "${extractdir}" -depth -exec rename 's/(.*)\/([^\/]*)/$1\/\L$2/' {} \;
		fn_print_ok "Converting ${modprettyname} files to lowercase"
		sleep 1
	fi
}

fn_remove_cfg_files(){
	# Remove config file after extraction for updates set by ${modkeepfiles}
	if [ "${modkeepfiles}" !=  "OVERWRITE" ]&&[ "${modkeepfiles}" != "NOUPDATE" ]; then
		# Upon mods updates, config files should not be overwritten
		# We will just remove these files before copying the mod to the destination
		# Let's count how many files there are to remove
		fn_print_dots_nl "Allow for preserving ${modprettyname} config files"
		sleep 0.5
		removefilesamount="$(echo "${modkeepfiles}" | awk -F ';' '{ print NF }')"
		# Test all subvalue of "modgames" using the ";" separator
		for ((removefilesindex=1; removefilesindex < ${removefilesamount}; removefilesindex++)); do
			# Put current file we're looking for into a variable
			filetoremove="$( echo "${modkeepfiles}" | awk -F ';' -v x=${removefilesindex} '{ print $x }' )"
			# If it matches an existing file that have been extracted
			if [ -f "${extractdir}/${filetoremove}" ]||[ -d "${extractdir}/${filetoremove}" ]; then
				# Then delete the file!
				rm -R "${extractdir}/${filetoremove}"
				# Write this file path in a tmp file, to rebuild a full file list
				if [ ! -f "${modsdatadir}/.removedfiles.tmp" ]; then
					touch "${modsdatadir}/.removedfiles.tmp"
				fi
					echo "${filetoremove}" >> "${modsdatadir}/.removedfiles.tmp"
			fi
		done
		fn_print_ok "Allow for preserving ${modprettyname} config files"
	fi
}

fn_mod_fileslist(){
	# Create lgsm/data/mods directory
	if [ ! -d "${modsdatadir}" ]; then
		mkdir -p "${modsdatadir}"
		fn_script_log "Created ${modsdatadir}"
	fi
	fn_print_dots_nl "Building ${modcommand}-files.list"
	fn_script_log "Building ${modcommand}-files.list"
	# ${modsdatadir}/${modcommand}-files.list
	find "${extractdir}" -mindepth 1 -printf '%P\n' > ${modsdatadir}/${modcommand}-files.list
	fn_script_log "Writing file list: ${modsdatadir}/${modcommand}-files.list}"
	# Adding removed files if needed
	if [ -f "${modsdatadir}/.removedfiles.tmp" ]; then
		cat "${modsdatadir}/.removedfiles.tmp" >> ${modsdatadir}/${modcommand}-files.list
	fi
	fn_print_ok "Building ${modcommand}-files.list"
}

fn_mod_copy_destination(){
	# Destination directory: ${modinstalldir}
	fn_print_dots_nl "Copying ${modprettyname} to ${modinstalldir}"
	fn_script_log "Copying ${modprettyname} to ${modinstalldir}"
	cp -Rf "${extractdir}/." "${modinstalldir}/"
}

# Check if the mod is already installed and warn the user
fn_mod_already_installed(){
	if [ -f "${modslockfilefullpath}" ]; then
		if [ -n "$(cat "${modslockfilefullpath}" | grep "${modcommand}")" ]; then
			fn_print_warning_nl "${modprettyname} has already been installed."
			echo " * Config files, if any, might be overwritten."
			echo " * Press ctrl + c to abort."
			sleep 4
		fi
	fn_script_log "${modprettyname} is already installed, overwriting any file."
	fi
}

# Add the mod to the installed mods list
fn_mod_add_list(){
	# Create lgsm/data/mods directory
	if [ ! -d  "${modsdatadir}" ]; then
		mkdir -p "${modsdatadir}"
		fn_script_log "Created ${modsdatadir}"
	fi
	# Create lgsm/data/${modslockfile}
	if [ ! -f "${modslockfilefullpath}" ]; then
		touch "${modslockfilefullpath}"
		fn_script_log "Created ${modslockfilefullpath}"
	fi
	# Input mod name to lockfile
	if [ ! -n "$(cat "${modslockfilefullpath}" | grep "${modcommand}")" ]; then
		echo "${modcommand}" > "${modslockfilefullpath}"
		fn_script_log "${modcommand} added to ${modslockfile}"
	fi
}

fn_check_files_list(){
	# File list must exist and be valid before any operation on it
	if [ -f "${modsdatadir}/${modcommand}-files.list" ]; then
	# How many lines is the file list
		modsfilelistsize="$(cat "${modsdatadir}/${modcommand}-files.list" | wc -l)"
		# If file list is empty
		if [ $modsfilelistsize -eq 0 ]; then
			fn_print_error_nl "${modcommand}-files.list is empty"
			echo "Exiting."
			fn_scrip_log_fatal "${modcommand}-files.list is empty"
			exitcode="2"
			core_exit.sh
		fi
	else
			fn_print_error_nl "${modsdatadir}/${modcommand}-files.list don't exist"
			echo "Exiting."
			fn_scrip_log_fatal "${modsdatadir}/${modcommand}-files.list don't exist"
			exitcode="2"
			core_exit.sh
	fi
}

fn_postinstall_tasks(){
	# Prevent addons folder from being removed by clearing them in: ${modsdatadir}/${modcommand}-files.list
	# Check file validity
	fn_check_files_list
	# Output to the user
	fn_print_dots "Rearranging ${modcommand}-files.list"
	sleep 1
	fn_script_log_info "Rearranging ${modcommand}-files.list"
	# What lines/files to remove from file list
	removefromlist="cfg;addons;"
	# Loop through files to remove from file list,
	# that way these files won't get removed upon uninstall
	# How many elements to remove from list
	removefromlistamount="$(echo "${removefromlist}" | awk -F ';' '{ print NF }')"
	# Test all subvalue of "removefromlist" using the ";" separator
	for ((filesindex=1; filesindex < ${removefromlistamount}; filesindex++)); do
		# Put current file into test variable
		removefilevar="$( echo "${removefromlist}" | awk -F ';' -v x=${filesindex} '{ print $x }' )"
		# Then delete matching line(s)!
		sed -i "/^${removefilevar}$/d" "${modsdatadir}/${modcommand}-files.list"
	done
	fn_print_ok "Rearranging ${modcommand}-files.list"
}
