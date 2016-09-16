#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de

# This module provides generic service handling for each program supporting
# standard process signals.
# In general you only have to replace the string "generic" to you specific
# application name.

# Dependencies:

# - bash (or any bash like shell)
# - date - Print or set the system date and time.
# - find - Search for files in a directory hierarchy.
# - test - Check file types and compare values.
# - msmtp - An SMTP client.

# Needed for the LSBInitScripts specification.
### BEGIN INIT INFO
# Provides:          generic
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: see above
# Description:       see above
### END INIT INFO
__NAME__='backupRotation'
# endregion
backupRotation() {
    # Provides the main module scope.
    # region constants
    local sourcePath='/tmp/source/'
    local targetPath='/tmp/backup/'
    local eMailAddress='' # Notification are disabled by default.
    local dailyTargetPath='daily/'
    local weeklyTargetPath='weekly/'
    local monthlyTargetPath='monthly/'
    local targetDailyFileName="$(date +'%d-%m-%Y')"
    local targetWeeklyFileName="$(date +'%V sav. %m-%Y')"
    local targetMonthlyFileName="$(date +'%m-%Y')"
    local backupWeekDayNumber=6 # Saturday
    local backupMonthDayNumber=1
    local numberOfDailyRetentionDays=14 # Daily backups for the last 14 days.
    local numberOfWeeklyRetentionDays=56 # Weekly backups for the last 2 month.
    local numberOfMonthlyRetentionDays=365 # Monthly backups for the last year.
    local backupCommand='rsync --recursive --delete --perms --executability --owner --group --times --devices --specials --acls --links --super --whole-file --force --protect-args --hard-links --max-delete=1 --progress --human-readable --itemize-changes --verbose "$sourcePath" "$targetFilePath" && tar --dereference --create --verbose --gzip --file "${targetFilePath}.tar.gz" "$targetFilePath" && rm --recursive --verbose "$targetFilePath"'
    # Folder to delete is the last command line argument.
    local cleanupCommand='rm --recursive --verbose'
    # endregion
    # region controller
    # Get current month and week day number
    local monthDayNumber="$(date +'%d')"
    local weekDayNumber="$(date +'%u')"
    # Check if source files exist and send an email if not
    if [ ! -d "$sourcePath" ]; then
        local date="$(date)"
        local message="Source files on \"$sourcePath\" should be backed up but aren't available."
        if [[ "$eMailAddress" != '' ]]; then
            msmtp -t <<EOF
From: $eMailAddress
To: $eMailAddress
Reply-To: $eMailAddress
Date: $date
Subject: Source files doesn't exist.

$message

EOF
        fi
        echo "$message" &>/dev/stderr
        return 1
    fi
    if [[ "$monthDayNumber" == "$backupMonthDayNumber" ]]; then
        local targetFilePath="${targetPath}${dailyTargetPath}${targetDailyFileName}"
    elif [[ "$weekDayNumber" == "$backupMontheDayNumber" ]]; then
        local targetFilePath="${targetPath}${dailyTargetPath}${targetDailyFileName}"
    else
        local targetFilePath="${targetPath}${dailyTargetPath}${targetDailyFileName}"
    fi
    mkdir --parents "$(dirname "$targetFilePath")"
    eval "$backupCommand"
    # Clean outdated daily backups.
    find "$targetPath" -mtime +"$numberOfDailyRetentionDays" -type d -exec \
        "$cleanupCommand" {} \;
    # Clean outdated weekly backups.
    find "$targetPath" -mtime +"$numberOfWeeklyRetentionDays" -type d -exec \
        "$cleanupCommand" {} \;
    # Clean outdated monthly backups.
    find "$targetPath" -mtime +"$numberOfMonthlyRetentionDays" -type d -exec \
        "$cleanupCommand" {} \;
    # endregion
    return $?
}
if [[ "$0" == *"${__NAME__}.sh" ]]; then
    "$__NAME__" "$@"
    exit $?
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion