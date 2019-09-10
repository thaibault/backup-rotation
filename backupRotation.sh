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
# region import
if [ -f "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh" ]
then
    # shellcheck disable=SC1090
    source "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh"
elif [ -f /usr/lib/bashlink/module.sh ]; then
    # shellcheck disable=SC1091
    source /usr/lib/bashlink/module.sh
else
    declare -gr backupRotation_bashlink_path="$(
        mktemp --directory --suffix -backup-rotation-bashlink
    )/bashlink/"
    mkdir "$backupRotation_bashlink_path"
    if wget \
        https://torben.website/bashlink/data/distributionBundle/module.sh \
        --output-document "${backupRotation_bashlink_path}module.sh"
    then
        declare -gr bl_module_retrieve_remote_modules=true
        # shellcheck disable=SC1090
        source "${backupRotation_bashlink_path}/module.sh"
        rm --force --recursive "$backupRotation_bashlink_path"
    else
        echo Needed bashlink library not found 1>&2
        rm --force --recursive "$backupRotation_bashlink_path"
        exit 1
    fi
fi
bl.module.import bashlink.exception
bl.module.import bashlink.logging
bl.module.import bashlink.tools
# endregion
# region variables
## region documentation
declare -gr backupRotation__documentation__='
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
    `backupRotation_source_target_mappings` at least:

    ```bash
        declare -A backupRotation_source_target_mappings=(
            ["SOURCE_URL1"]="TARGET_URL1 RECIPIENT_E_MAIL_ADDRESS"
            ["SOURCE_URL2"]="TARGET_URL2 RECIPIENT_E_MAIL_ADDRESS ANOTHER_RECIPIENT_E_MAIL_ADDRESS"
            ...
        )
    ```
'
declare -agr backupRotation__dependencies__=(
    bash
    date
    find
    msmtp
    test
    tree
)
## endregion
## region default options
declare -Ag backupRotation_source_target_mappings=()

# Disables by e-mail sending if empty.
declare -g backupRotation_sender_e_mail_address=''
declare -g backupRotation_replier_e_mail_address="$backupRotation_sender_e_mail_address"

declare -g backupRotation_daily_target_path=daily/
declare -g backupRotation_weekly_target_path=weekly/
declare -g backupRotation_monthly_target_path=monthly/

declare -g backupRotation_target_daily_file_basename="$(date +'%d-%m-%Y')"
declare -g backupRotation_target_weekly_file_basename="$(
    date +'%V.week-')${backupRotation_target_daily_file_basename}"
declare -g backupRotation_target_monthly_file_basename="$backupRotation_target_daily_file_basename"

# Should be in range 1 till 28
declare -gi backupRotation_month_day_number=1
# Should be in range 1 till 7
declare -gi backupRotation_week_day_number=6 # Saturday

# Creates daily backups for the last 14 days.
declare -gi backupRotation_number_of_daily_retention_days=14
# Creates weekly backups for the last 2 month.
declare -gi backupRotation_number_of_weekly_retention_days=56
# Creates monthly backups for the last year.
declare -gi backupRotation_number_of_monthly_retention_days=365

declare -g backupRotation_target_file_baseextension=.tar.gz
declare -g backupRotation_target_file_extension="${backupRotation_target_file_baseextension}.gpg"

declare -g backupRotation_command_default_arguments='--acls --delete --devices --exclude=backup --exclude=done --exclude=log --exclude=migration --exclude=mockup --exclude=node_modules --exclude=preRendered --exclude=readme.md --exclude=.cache --exclude=.git --exclude=.local --exclude=.ssh --exclude=.yarn --exclude=.m2 --exclude=.npm --executability --force --group --hard-links --human-readable --itemize-changes --links --max-delete=1 --owner --perms --progress --protect-args --specials --recursive --super --times --verbose --whole-file'
declare -g backupRotation_command=''
# NOTE: Encrypt with per batch mode:
# cat /etc/backupRotationPassword | gpg --batch --decrypt --no-symkey-cache --output "${target_file_basepath}${backupRotation_target_file_baseextension}" --passphrase-fd 0 --pinentry-mode loopback "${target_file_basepath}${backupRotation_target_file_extension}"
# or interactively:
# gpg --decrypt --no-symkey-cache --output "${target_file_basepath}${backupRotation_target_file_baseextension}" "${target_file_basepath}${backupRotation_target_file_extension}"
declare -g backupRotation_encrypt_command='if [ -s /etc/backupRotationPassword ]; then rm "${target_file_basepath}${backupRotation_target_file_extension}" &>/dev/null; cat /etc/backupRotationPassword | gpg --batch --no-symkey-cache --output "${target_file_basepath}${backupRotation_target_file_extension}" --passphrase-fd 0 --pinentry-mode loopback --symmetric "${target_file_basepath}${backupRotation_target_file_baseextension}" && rm "${target_file_basepath}${backupRotation_target_file_baseextension}"; else true; fi'

declare -g backupRotation_post_run_command=''
# Folder to delete is the last command line argument.
declare -g backupRotation_cleanup_command='rm --recursive --verbose'
declare -g backupRotation_verbose=false
declare -g backupRotation_monitoring_url=''
declare -g backupRotation_name=NODE_NAME
## endregion
## region load options if present and not empty
if [ -s /etc/backupRotation ]; then
    # shellcheck disable=SC1091
    source /etc/backupRotation
fi
if [ "$backupRotation_encrypt_command" = '' ]; then
    backupRotation_target_file_extension="$backupRotation_target_file_baseextension"
fi
if [ "$backupRotation_command" = '' ]; then
    backupRotation_command="rsync $backupRotation_command_default_arguments "'"$source_path" "$target_file_basepath" && pushd "$(dirname "$target_file_basepath")" && tar --create --verbose --gzip --file "${target_file_basepath}${backupRotation_target_file_baseextension}" "$(basename "$target_file_basepath")"; popd && rm --recursive --verbose "$target_file_basepath"'
fi
## endregion
# endregion
# region controller
alias backupRotation.main=backupRotation_main
backupRotation_main() {
    local -r __documentation__='
        Get current month and week day number
    '
    if $backupRotation_verbose; then
        bl.logging.set_level info
    fi
    local -ir month_day_number="$(
        date +'%d' | \
            command grep '[1-9][0-9]?' --only-matching --extended-regexp)"
    local -ir week_day_number="$(date +'%u')"
    local source_path
    for source_path in "${!backupRotation_source_target_mappings[@]}"; do
        local target_path="$(
            echo "${backupRotation_source_target_mappings[$source_path]}" | \
                command grep '^[^ ]+' --only-matching --extended-regexp)"
        local target_file_basepath="${target_path}/${backupRotation_daily_target_path}${backupRotation_target_daily_file_basename}"
        if (( backupRotation_month_day_number == month_day_number )); then
            target_file_basepath="${target_path}/${backupRotation_monthly_target_path}${backupRotation_target_monthly_file_basename}"
            ln \
                --force \
                --symbolic \
                "${target_file_basepath}${backupRotation_target_file_extension}" \
                "${target_path}/${backupRotation_daily_target_path}${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}"
            if (( backupRotation_week_day_number == week_day_number )); then
                ln \
                    --force \
                    --symbolic \
                    "${target_file_basepath}${backupRotation_target_file_extension}" \
                    "${target_path}/${backupRotation_weekly_target_path}${backupRotation_target_weekly_file_basename}${backupRotation_target_file_extension}"
            fi
        elif (( backupRotation_week_day_number == week_day_number )); then
            target_file_basepath="${target_path}/${backupRotation_weekly_target_path}${backupRotation_target_weekly_file_basename}"
            ln \
                --force \
                --symbolic \
                "${target_file_basepath}${backupRotation_target_file_extension}" \
                "${target_path}/${backupRotation_daily_target_path}${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}"
        fi
        mkdir --parents "$(dirname "$target_file_basepath")"
        if bl.logging.is_enabled info; then
            echo "Running \"${backupRotation_command}\"."
        else
            backupRotation_command+="${backupRotation_command} &>/dev/null"
        fi
        local successful=false
        if eval "$backupRotation_command"; then
            if [[ "$backupRotation_encrypt_command" != '' ]]; then
                if eval "$backupRotation_encrypt_command"; then
                    successful=true
                fi
            else
                successful=true
            fi
            # Clean outdated daily backups.
            if [ -d "${target_path}/${backupRotation_daily_target_path}" ]; then
                # shellcheck disable=SC2086
                find \
                    "${target_path}/${backupRotation_daily_target_path}" \
                    -mtime +"$backupRotation_number_of_daily_retention_days" \
                    -exec $backupRotation_cleanup_command {} \;
            fi
            # Clean outdated weekly backups.
            if [ -d "${target_path}/${backupRotation_weekly_target_path}" ]; then
                # shellcheck disable=SC2086
                find \
                    "${target_path}/${backupRotation_weekly_target_path}" \
                    -mtime +"$backupRotation_number_of_weekly_retention_days" \
                    -exec $backupRotation_cleanup_command {} \;
            fi
            # Clean outdated monthly backups.
            if [ -d "${target_path}/${backupRotation_monthly_target_path}" ]; then
                # shellcheck disable=SC2086
                find \
                    "${target_path}/${backupRotation_monthly_target_path}" \
                    -mtime +"$backupRotation_number_of_monthly_retention_days" \
                    -exec $backupRotation_cleanup_command {} \;
            fi
            if \
                $successful && \
                [[ "$backupRotation_post_run_command" != '' ]] && \
                ! eval "$backupRotation_post_run_command"
            then
                successful=false
            fi
            if $successful; then
                # shellcheck disable=SC2089
                local message="Source files in \"$source_path\" from node \"$backupRotation_name\" successfully backed up to \"${target_file_basepath}${backupRotation_target_file_extension}\"."$'\n\nCurrent Backup structure:\n'
                if bl.logging.is_enabled info; then
                    echo -e "$message"
                    tree -h -t "$target_path"
                    du --human-readable --summarize "$target_path"
                    df ./ --human-readable
                fi
                if hash msmtp && [[ "$backupRotation_sender_e_mail_address" != '' ]]; then
                    local e_mail_address
                    for e_mail_address in \
                        $(echo "${backupRotation_source_target_mappings[$source_path]}" | \
                            command grep ' .+$' --only-matching --extended-regexp)
                    do
                        msmtp --read-recipients <<EOF
MIME-Version: 1.0
Content-Type: text/html
From: $backupRotation_sender_e_mail_address
To: $e_mail_address
Reply-To: $backupRotation_replier_e_mail_address
Date: $(date)
Subject: Backup was successful

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
                sed "0,/${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}/s/${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}<\\/span>/" | \
                    sed "s/${backupRotation_target_weekly_file_basename}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_weekly_file_basename}${backupRotation_target_file_extension}<\\/span>/" | \
                        sed "s/${backupRotation_target_monthly_file_basename}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_monthly_file_basename}${backupRotation_target_file_extension}<\\/span>/"
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
                fi
                if [[ "$backupRotation_monitoring_url" != '' ]]; then
                    curl \
                        --data "{\"source\": \"$source_path\", \"target\": \"$target_path\", \"error\": false}" \
                        --header 'Content-Type: application/json' \
                        --request PUT \
                        "$backupRotation_monitoring_url"
                fi
            fi
        fi
        if ! $successful; then
            local message="Source files in \"$source_path\" from node \"$backupRotation_name\" should be backed up but has failed."$'\n\nCurrent Backup structure:\n'
            if bl.logging.is_enabled info; then
                bl.logging.info "$message"
                tree -h -t "$target_path"
                du --human-readable --summarize "$target_path"
                df ./ --human-readable
            fi
            if hash msmtp && [[ "$backupRotation_sender_e_mail_address" != '' ]]; then
                local e_mail_address
                for e_mail_address in \
                    $(echo "${backupRotation_source_target_mappings[$source_path]}" | \
                        command grep ' .+$' --only-matching --extended-regexp)
                do
                    msmtp --read-recipients <<EOF
MIME-Version: 1.0
Content-Type: text/html
From: $backupRotation_sender_e_mail_address
To: $e_mail_address
Reply-To: $backupRotation_replier_e_mail_address
Date: $(date)
Subject: Backup has failed

<!doctype html>
<html>
<head>
</head>
<body>
    <p>$(
        echo -e "$message" | \
            sed --regexp-extended 's/"([^"]+)"/"<span style="font-weight:bold">\1<\/span>"/g' | \
                sed --regexp-extended 's/(failed)/<span style="font-weight:bold">\1<\/span>/g'
    )</p>
    <p>
        <pre>
$(
    tree -h -t "$target_path" | \
        sed 's/</\&lt;/g' | \
            sed 's/>/\&gt;/g' | \
                sed "0,/${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}/s/${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_daily_file_basename}${backupRotation_target_file_extension}<\\/span>/" | \
                    sed "s/${backupRotation_target_weekly_file_basename}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_weekly_file_basename}${backupRotation_target_file_extension}<\\/span>/" | \
                        sed "s/${backupRotation_target_monthly_file_basename}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_monthly_file_basename}${backupRotation_target_file_extension}<\\/span>/"
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
                if [[ "$backupRotation_monitoring_url" != '' ]]; then
                    curl \
                        --data "{\"source\": \"$source_path\", \"target\": \"$target_path\", \"error\": true}" \
                        --header 'Content-Type: application/json' \
                        --request PUT \
                        "$backupRotation_monitoring_url"
                fi
            fi
            exit 1
        fi
    done
}
# endregion
if bl.tools.is_main; then
    bl.exception.activate
    bl.exception.try
        backupRotation.main "$@"
    bl.exception.catch_single
    # region clean up
    {
        [ -d "$backupRotation_bashlink_path" ] && \
            rm --recursive "$backupRotation_bashlink_path"
        # shellcheck disable=SC2154
        [ -d "$bl_module_remote_module_cache_path" ] && \
            rm --recursive "$bl_module_remote_module_cache_path"
        # shellcheck disable=SC2154
        bl.logging.error "$bl_exception_last_traceback"
    }
    [ -d "$backupRotation_bashlink_path" ] && \
        rm --recursive "$backupRotation_bashlink_path"
    # shellcheck disable=SC2154
    [ -d "$bl_module_remote_module_cache_path" ] && \
        rm --recursive "$bl_module_remote_module_cache_path"
    # endregion
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
