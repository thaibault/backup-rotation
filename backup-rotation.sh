#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# [Project page](https://torben.website/backupRotation)

# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. See https://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC1004,SC2016,SC2034,SC2155
shopt -s expand_aliases
# region import
alias br.download=br_download
br_download() {
    local -r __documentation__='
        Simply downloads missing modules.

        >>> br.download --silent https://domain.tld/path/to/file.ext; echo $?
        6
    '
    command curl --insecure "$@"
    return $?
}

if [ -f "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh" ]; then
    # shellcheck disable=SC1090
    source "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh"
elif [ -f "/usr/lib/bashlink/module.sh" ]; then
    # shellcheck disable=SC1091
    source "/usr/lib/bashlink/module.sh"
else
    declare -g BR_CACHE_PATH=/tmp/backupRotationInstallCache/
    declare -gr BL_MODULE_REMOTE_MODULE_CACHE_PATH="${BR_CACHE_PATH}bashlink"
    mkdir --parents "$BL_MODULE_REMOTE_MODULE_CACHE_PATH"
    declare -gr BL_MODULE_RETRIEVE_REMOTE_MODULES=true
    if ! (
        [ -f "${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh" ] || \
        br.download \
            https://raw.githubusercontent.com/thaibault/bashlink/main/module.sh \
                >"${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh"
    ); then
        echo Needed bashlink library could not be retrieved. 1>&2
        rm \
            --force \
            --recursive \
            "${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${BL_MODULE_REMOTE_MODULE_CACHE_PATH}/module.sh"
fi
bl.module.import bashlink.exception
bl.module.import bashlink.logging
bl.module.import bashlink.tools
# endregion
# region variables
## region documentation
declare -gr BR__DOCUMENTATION__='
    This module provides generic service handling for each program supporting
    standard process signals. In general you only have to replace the string
    "generic" to you specific application name.

    You have to install program `msmtp` to get this script working. A proper
    user specific "~/.msmtprc" or global "/etc/msmtprc" have to be present on
    your distribution. A sample configuration using simple gmail account to
    send mails (Replace `ACCOUNT_NAME`, `ACCOUNT_E_MAIL_ADDRESS`,
    `ACCOUNT_PASSWORD`, `RECIPIENT_E_MAIL_ADDRESS`):

    ```
        defaults
        auth           on
        tls            on
        tls_starttls   on
        tls_trust_file /etc/ssl/certs/ca-certificates.crt
        logfile        /tmp/msmtpLog

        account        gmail
        host           smtp.gmail.com
        port           587
        from           ACCOUNT_E_MAIL_ADDRESS
        user           ACCOUNT_NAME@gmail.com
        password       ACCOUNT_PASSWORD

        account        default : gmail
    ```

    Furthermore you should create a file "/etc/backupRotation" to overwrite the
    following variables. You need to set values for
    `BR_SOURCE_TARGET_MAPPINGS` at least:

    ```bash
        declare -A BR_SOURCE_TARGET_MAPPINGS=(
            ["SOURCE_URL1"]="TARGET_URL1 RECIPIENT_E_MAIL_ADDRESS"
            ["SOURCE_URL2"]="TARGET_URL2 RECIPIENT_E_MAIL_ADDRESS ANOTHER_RECIPIENT_E_MAIL_ADDRESS"
            ...
        )
    ```
'
declare -agr BR__DEPENDENCIES__=(
    bash
    date
    find
    msmtp
    test
    tree
)
## endregion
## region default options
declare -Ag BR_SOURCE_TARGET_MAPPINGS=()

declare -g BR_SEND_SUCCESS_E_MAILS=true
# Disables by setting e-mail address to an empty string.
declare -g BR_SENDER_E_MAIL_ADDRESS=''
declare -g BR_REPLIER_E_MAIL_ADDRESS="$BR_SENDER_E_MAIL_ADDRESS"

declare -g BR_DAILY_TARGET_PATH=daily/
declare -g BR_WEEKLY_TARGET_PATH=weekly/
declare -g BR_MONTHLY_TARGET_PATH=monthly/

declare -g BR_TARGET_DAILY_FILE_BASENAME="$(date +'%d-%m-%Y')"
declare -g BR_TARGET_WEEKLY_FILE_BASENAME="$(
    date +'%V.week-')${BR_TARGET_DAILY_FILE_BASENAME}"
declare -g BR_TARGET_MONTHLY_FILE_BASENAME="$BR_TARGET_DAILY_FILE_BASENAME"

# Should be in range 1 till 28
declare -gi BR_MONTH_DAY_NUMBER=1
# Should be in range 1 till 7
declare -gi BR_WEEK_DAY_NUMBER=6 # Saturday

# Creates daily backups for the last 14 days.
declare -gi BR_NUMBER_OF_DAILY_RETENTION_DAYS=14
# Creates weekly backups for the last 2 month.
declare -gi BR_NUMBER_OF_WEEKLY_RETENTION_DAYS=56
# Creates monthly backups for the last year.
declare -gi BR_NUMBER_OF_MONTHLY_RETENTION_DAYS=365

declare -g BR_TARGET_FILE_BASE_EXTENSION=.tar.gz
declare -g BR_TARGET_FILE_EXTENSION="${BR_TARGET_FILE_BASE_EXTENSION}.gpg"

declare -g BR_COMMAND_DEFAULT_ARGUMENTS='--acls --delete --devices --exclude=backup --exclude=done --exclude=log --exclude=migration --exclude=mockup --exclude=node_modules --exclude=preRendered --exclude=readme.md --exclude=.cache --exclude=.git --exclude=.local --exclude=.m2 --exclude=.node-gyp --exclude=.npm --exclude=.ssh --exclude=.yarn --executability --force --group --hard-links --human-readable --itemize-changes --links --max-delete=1 --owner --perms --progress --protect-args --specials --recursive --super --times --verbose --whole-file'
declare -g BR_COMMAND=''
declare -g BR_ENCRYPT_COMMAND=''
if [ -s /etc/backupRotationPassword ]; then
    # NOTE: Encrypt with per batch mode:
    # cat /etc/backupRotationPassword | gpg --batch --decrypt --no-symkey-cache --output "${target_file_basepath}${BR_TARGET_FILE_BASE_EXTENSION}" --passphrase-fd 0 --pinentry-mode loopback "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}"
    # or interactively:
    # gpg --decrypt --no-symkey-cache --output "${target_file_basepath}${BR_TARGET_FILE_BASE_EXTENSION}" "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}"
    BR_ENCRYPT_COMMAND='rm "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}" &>/dev/null; cat /etc/backupRotationPassword | gpg --batch --no-symkey-cache --output "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}" --passphrase-fd 0 --pinentry-mode loopback --symmetric "${target_file_basepath}${BR_TARGET_FILE_BASE_EXTENSION}" && rm "${target_file_basepath}${BR_TARGET_FILE_BASE_EXTENSION}"'
fi

declare -g BR_POST_RUN_COMMAND=''
# Folder to delete is the last command line argument.
declare -g BR_CLEANUP_COMMAND='rm --recursive --verbose'
declare -g BR_VERBOSE=false
declare -g BR_MONITORING_URL=''
declare -g BR_NAME=NODE_NAME
## endregion
## region load options if present and not empty
if [ -s /etc/backupRotation ]; then
    # shellcheck disable=SC1091
    source /etc/backupRotation
fi
if [ "$BR_ENCRYPT_COMMAND" = '' ]; then
    BR_TARGET_FILE_EXTENSION="$BR_TARGET_FILE_BASE_EXTENSION"
fi
if [ "$BR_COMMAND" = '' ]; then
    BR_COMMAND="rsync $BR_COMMAND_DEFAULT_ARGUMENTS "'"$source_path" "$target_file_basepath" && pushd "$(dirname "$target_file_basepath")" && tar --create --verbose --gzip --file "${target_file_basepath}${BR_TARGET_FILE_BASE_EXTENSION}" "$(basename "$target_file_basepath")"; popd && rm --recursive --verbose "$target_file_basepath"'
fi
## endregion
BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^backupRotation([._][a-zA-Z_-]+)?$/br\1/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^BACKUP_ROTATION(_[a-zA-Z_-]+)?$/BR\1/')
# endregion
# region controller
alias br.main=br_main
br_main() {
    local -r __documentation__='
        Get current month and week day number
    '
    if $BR_VERBOSE; then
        bl.logging.set_level info
    fi
    local -ir month_day_number="$(
        date +'%d' | \
            command grep '[1-9][0-9]?' --only-matching --extended-regexp
    )"
    local -ir week_day_number="$(date +'%u')"
    local source_path
    for source_path in "${!BR_SOURCE_TARGET_MAPPINGS[@]}"; do
        local target_path="$(
            echo "${BR_SOURCE_TARGET_MAPPINGS[$source_path]}" | \
                command grep '^[^ ]+' --only-matching --extended-regexp
        )"
        local target_file_basepath="${target_path}/${BR_DAILY_TARGET_PATH}${BR_TARGET_DAILY_FILE_BASENAME}"
        if (( BR_MONTH_DAY_NUMBER == month_day_number )); then
            target_file_basepath="${target_path}/${BR_MONTHLY_TARGET_PATH}${BR_TARGET_MONTHLY_FILE_BASENAME}"

            link_target_file_path="${target_path}/${BR_DAILY_TARGET_PATH}${BR_TARGET_DAILY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}"
            mkdir --parents "$(dirname "$link_target_file_path")"

            ln \
                --force \
                --symbolic \
                "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}" \
                "$link_target_file_path"
            if (( BR_WEEK_DAY_NUMBER == week_day_number )); then
                link_target_file_path="${target_path}/${BR_WEEKLY_TARGET_PATH}${BR_TARGET_WEEKLY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}"
                mkdir --parents "$(dirname "$link_target_file_path")"

                ln \
                    --force \
                    --symbolic \
                    "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}" \
                    "$link_target_file_path"
            fi
        elif (( BR_WEEK_DAY_NUMBER == week_day_number )); then
            target_file_basepath="${target_path}/${BR_WEEKLY_TARGET_PATH}${BR_TARGET_WEEKLY_FILE_BASENAME}"

            link_target_file_path="${target_path}/${BR_DAILY_TARGET_PATH}${BR_TARGET_DAILY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}"
            mkdir --parents "$(dirname "$link_target_file_path")"

            ln \
                --force \
                --symbolic \
                "${target_file_basepath}${BR_TARGET_FILE_EXTENSION}" \
                "$link_target_file_path"
        fi
        mkdir --parents "$(dirname "$target_file_basepath")"
        if bl.logging.is_enabled info; then
            echo "Running \"${BR_COMMAND}\"."
        else
            BR_COMMAND+="${BR_COMMAND} &>/dev/null"
        fi
        if eval "$BR_COMMAND"; then
            local successful=false
            if [[ "$BR_ENCRYPT_COMMAND" != '' ]]; then
                if eval "$BR_ENCRYPT_COMMAND"; then
                    successful=true
                fi
            else
                successful=true
            fi
            # Clean outdated daily backups.
            if [ -d "${target_path}/${BR_DAILY_TARGET_PATH}" ]; then
                bl.logging.info Clearing old daily backups:
                find \
                    "${target_path}/${BR_DAILY_TARGET_PATH}" \
                    -mtime +"$BR_NUMBER_OF_DAILY_RETENTION_DAYS"
                # shellcheck disable=SC2086
                find \
                    "${target_path}/${BR_DAILY_TARGET_PATH}" \
                    -mtime +"$BR_NUMBER_OF_DAILY_RETENTION_DAYS" \
                    -exec $BR_CLEANUP_COMMAND {} \;
            fi
            # Clean outdated weekly backups.
            if [ -d "${target_path}/${BR_WEEKLY_TARGET_PATH}" ]; then
                bl.logging.info Clearing old weekly backups:
                find \
                    "${target_path}/${BR_WEEKLY_TARGET_PATH}" \
                    -mtime +"$BR_NUMBER_OF_WEEKLY_RETENTION_DAYS"
                # shellcheck disable=SC2086
                find \
                    "${target_path}/${BR_WEEKLY_TARGET_PATH}" \
                    -mtime +"$BR_NUMBER_OF_WEEKLY_RETENTION_DAYS" \
                    -exec $BR_CLEANUP_COMMAND {} \;
            fi
            # Clean outdated monthly backups.
            if [ -d "${target_path}/${BR_MONTHLY_TARGET_PATH}" ]; then
                bl.logging.info Clearing old monthly backups:
                find \
                    "${target_path}/${BR_MONTHLY_TARGET_PATH}" \
                    -mtime +"$BR_NUMBER_OF_MONTHLY_RETENTION_DAYS"
                # shellcheck disable=SC2086
                find \
                    "${target_path}/${BR_MONTHLY_TARGET_PATH}" \
                    -mtime +"$BR_NUMBER_OF_MONTHLY_RETENTION_DAYS" \
                    -exec $BR_CLEANUP_COMMAND {} \;
            fi
            if \
                $successful && \
                [[ "$BR_POST_RUN_COMMAND" != '' ]] && \
                ! eval "$BR_POST_RUN_COMMAND"
            then
                successful=false
            fi
            local message="Source files in \"$source_path\" from node \"$BR_NAME\" "
            if $successful; then
                message+="successfully backed up to \"${target_file_basepath}${BR_TARGET_FILE_EXTENSION}\"."
            else
                message+='should be backed up but has failed.'
            fi
            message+='\n\nCurrent Backup structure:\n'
            if bl.logging.is_enabled info; then
                echo -e "$message"
                tree -h -t "$target_path"
                du --human-readable --summarize "$target_path"
                df ./ --human-readable
            fi
            if \
                ( ! $successful || $BR_SEND_SUCCESS_E_MAILS ) && \
                hash msmtp && \
                [[ "$BR_SENDER_E_MAIL_ADDRESS" != '' ]]
            then
                local e_mail_address
                for e_mail_address in $(
                    echo "${BR_SOURCE_TARGET_MAPPINGS[$source_path]}" | \
                        command grep ' .+$' --only-matching --extended-regexp
                ); do
                    msmtp --read-recipients <<EOF
MIME-Version: 1.0
Content-Type: text/html
From: $BR_SENDER_E_MAIL_ADDRESS
To: $e_mail_address
Reply-To: $BR_REPLIER_E_MAIL_ADDRESS
Date: $(date)
Subject: $(if $successful; then echo Backup was successful; else echo Backup has failed; fi)



<!doctype html>
<html>
<head>
</head>
<body>
    <p>$(
        echo -e "$message" | \
            sed --regexp-extended 's/"([^"]+)"/"<span style="font-weight:bold">\1<\/span>"/g'
    )</p>
    <p>
        <pre>
$(
    tree -h -t "$target_path" | \
        sed 's/</\&lt;/g' | \
            sed 's/>/\&gt;/g' | \
                sed "0,/${BR_TARGET_DAILY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}/s/${BR_TARGET_DAILY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}/<span style=\"font-weight:bold\">${BR_TARGET_DAILY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}<\\/span>/" | \
                    sed "s/${BR_TARGET_WEEKLY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}/<span style=\"font-weight:bold\">${BR_TARGET_WEEKLY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}<\\/span>/" | \
                        sed "s/${BR_TARGET_MONTHLY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}/<span style=\"font-weight:bold\">${BR_TARGET_MONTHLY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}<\\/span>/"
)
        </pre>
    </p>
    <p><pre>$(
        du --human-readable --summarize "$target_path" && \
        df ./ --human-readable
    )</pre></p>
</body>
</html>

EOF
                done
                if [[ "$BR_MONITORING_URL" != '' ]]; then
                    curl \
                        --data "{\"source\": \"$source_path\", \"target\": \"$target_path\", \"error\": false}" \
                        --header 'Content-Type: application/json' \
                        --request PUT \
                        "$BR_MONITORING_URL"
                fi
            fi
        fi
    done
}
# endregion
if bl.tools.is_main; then
    bl.exception.activate
    bl.exception.try
        br.main "$@"
    bl.exception.catch_single
    # region clean up
    {
        [ -f "$BL_MODULE_NAME_RESOLVING_CACHE_FILE_PATH" ] && \
            rm "$BL_MODULE_NAME_RESOLVING_CACHE_FILE_PATH"
        # shellcheck disable=SC2154
        [ -d "$BL_MODULE_REMOTE_MODULE_CACHE_PATH" ] && \
            rm --recursive "$BL_MODULE_REMOTE_MODULE_CACHE_PATH"
        # shellcheck disable=SC2154
        bl.logging.error "$BL_EXCEPTION_LAST_TRACEBACK"
    }
    [ -f "$BL_MODULE_NAME_RESOLVING_CACHE_FILE_PATH" ] && \
        rm "$BL_MODULE_NAME_RESOLVING_CACHE_FILE_PATH"
    # shellcheck disable=SC2154
    [ -d "$BL_MODULE_REMOTE_MODULE_CACHE_PATH" ] && \
        rm --recursive "$BL_MODULE_REMOTE_MODULE_CACHE_PATH"
    # endregion
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
