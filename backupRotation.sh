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
# - test - Check file types and compare values.
# - echo - Display a line of text.
# - cat  - Concatenate files and print on the standard output.
# - ps   - Report a snapshot of the current processes.
# - sed  - Stream editor for filtering and transforming text.
# - grep - Searches the named input files (or standard input if no files are
#          named, or if a single hyphen-minus (-) is given as file name) for
#          lines containing a match to the given PATTERN. By default, grep
#          prints the matching lines.
# - kill - Terminate a specified process.
# - rm   - Remove files or directories.
# - tail - Output the last part of files.
# - tee  - read from standard input and write to standard output and files

# Optional dependencies:

# - sudo - Perform action as another user.

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
function backupRotation() {
    # Provides the main module scope.
    # region constants

    # endregion
    # region controller
    if [[ "$1" == status ]]; then
        echo TODO
    else
        cat << EOF
$__NAME__ is a service handler for "$PROGRAM_CALL"

Usage "$0" [status|start|stop|restart|reload]"
EOF
    fi
    # endregion
    return $?
}
# region footer
if [[ "$0" == *"${__NAME__}.sh" ]]; then
    "$__NAME__" "$@"
    exit $?
fi
# endregion
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
