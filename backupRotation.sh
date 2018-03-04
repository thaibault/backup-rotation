#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# Copyright Torben Sickert (info["~at~"]torben.website) 16.12.2012

# License
# -------

# This library written by Torben Sickert stand under a creative commons naming
# 3.0 unported license. see http://creativecommons.org/licenses/by/3.0/deed.de
# endregion
# shellcheck disable=SC1004,SC2016,SC2034,SC2155
# region import
if [ -f "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh" ]; then
    # shellcheck disable=SC1090
    source "$(dirname "${BASH_SOURCE[0]}")/node_modules/bashlink/module.sh"
elif [ -f "/usr/lib/bashlink/module.sh" ]; then
    # shellcheck disable=SC1091
    source "/usr/lib/bashlink/module.sh"
else
    backupRotation_bashlink_path="$(mktemp --directory --suffix -backup-rotation-bashlink)/bashlink/"
    mkdir "$backupRotation_bashlink_path"
    echo wget \
        https://goo.gl/UKF5JG \
        --output-document "${backupRotation_bashlink_path}module.sh"
    if wget \
        https://goo.gl/UKF5JG \
        --output-document "${backupRotation_bashlink_path}module.sh"
    then
        bl_module_retrieve_remote_modules=true
        # shellcheck disable=SC1090
        source "${backupRotation_bashlink_path}/module.sh"
    else
        echo Needed bashlink library not found 1>&2
        #rm --force --recursive "$backupRotation_bashlink_path"
        exit 1
    fi
fi
bl.module.import bashlink.exception
bl.module.import bashlink.logging
bl.module.import bashlink.tools
# endregion
# region variables
backupRotation__dependencies__=(
    bash
    date
    find
    msmtp
    test
)
backupRotation__documentation__='
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
## region default options
declare -A backupRotation_source_target_mappings=()
# Disables by e-mail sending if empty.
backupRotation_sender_e_mail_address=''
backupRotation_replier_e_mail_address="$backupRotation_sender_e_mail_address"
backupRotation_daily_target_path=daily/
backupRotation_weekly_target_path=weekly/
backupRotation_monthly_target_path=monthly/
backupRotation_target_daily_file_name="$(date +'%d-%m-%Y')"
backupRotation_target_weekly_file_name="$(date +'%V.week-')${backupRotation_target_daily_file_name}"
backupRotation_target_monthly_file_name="$backupRotation_target_daily_file_name"
# Should be in range 1 till 28
backupRotation_month_day_number=1
# Should be in range 1 till 7
backupRotation_week_day_number=6 # Saturday
# Creates daily backups for the last 14 days.
backupRotation_number_of_daily_retention_days=14
# Creates weekly backups for the last 2 month.
backupRotation_number_of_weekly_retention_days=56
# Creates monthly backups for the last year.
backupRotation_number_of_monthly_retention_days=365
backupRotation_target_file_extension=.tar.gz
backupRotation_command='rsync --recursive --delete --perms --executability --owner --group --times --devices --specials --acls --links --super --whole-file --force --protect-args --hard-links --max-delete=1 --progress --human-readable --itemize-changes --verbose --exclude=.git --exclude=.npm --exclude=node_modules --exclude=.local "$source_path" "$target_file_path" && tar --create --verbose --gzip --file "${target_file_path}${target_file_extension}" "$target_file_path"; rm --recursive --verbose "$target_file_path"'
backupRotation_post_run_command=''
# Folder to delete is the last command line argument.
backupRotation_cleanup_command='rm --recursive --verbose'
backupRotation_verbose=false
backupRotation_monitoring_url=''
backupRotation_name=NODE_NAME
## endregion
## region load options if present
if [ -f /etc/backupRotation ]; then
    bl.module.import /etc/backupRotation
fi
## endregion
# endregion
# region functions
## region controller
alias backupRotation.main=backupRotation_main
backupRotation_main() {
    # Get current month and week day number
    local month_day_number="$(
        date +'%d' | grep '[1-9][0-9]?' --only-matching --extended-regexp)"
    local week_day_number="$(date +'%u')"
    local source_path
    for source_path in "${!backupRotation_source_target_mappings[@]}"; do
        local target_path="$(
            echo "${backupRotation_source_target_mappings[$source_path]}" | \
                grep '^[^ ]+' --only-matching --extended-regexp)"
        local target_file_path="${target_path}/${backupRotation_daily_target_path}${backupRotation_target_daily_file_name}"
        if (( backupRotation_month_day_number == month_day_number )); then
            target_file_path="${target_path}/${backupRotation_monthly_target_path}${backupRotation_target_monthly_file_name}"
            ln \
                --force \
                --symbolic \
                "${target_file_path}${backupRotation_target_file_extension}" \
                "${target_path}/${backupRotation_daily_target_path}${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}"
            if (( backupRotation_week_day_number == week_day_number )); then
                ln \
                    --force \
                    --symbolic \
                    "${target_file_path}${backupRotation_target_file_extension}" \
                    "${target_path}/${backupRotation_weekly_target_path}${backupRotation_target_weekly_file_name}${backupRotation_target_file_extension}"
            fi
        elif (( backupRotation_week_day_number == week_day_number )); then
            target_file_path="${target_path}/${backupRotation_weekly_target_path}${backupRotation_target_weekly_file_name}"
            ln \
                --force \
                --symbolic \
                "${target_file_path}${backupRotation_target_file_extension}" \
                "${target_path}/${backupRotation_daily_target_path}${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}"
        fi
        mkdir --parents "$(dirname "$target_file_path")"
        if $backupRotation_verbose; then
            echo "Running \"${backupRotation_command}\"."
        else
            backupRotation_command+="${backupRotation_command} &>/dev/null"
        fi
        local successful=false
        if eval "$backupRotation_command"; then
            # Clean outdated daily backups.
            [ -d "${target_path}/${backupRotation_daily_target_path}" ] && \
                find \
                    "${target_path}/${backupRotation_daily_target_path}" \
                    -mtime +"$backupRotation_number_of_daily_retention_days" \
                    -exec "${backupRotation_cleanup_command[*]}" {} \;
            # Clean outdated weekly backups.
            if [ -d "${target_path}/${backupRotation_weekly_target_path}" ]; then
                find \
                    "${target_path}/${backupRotation_weekly_target_path}" \
                    -mtime +"$backupRotation_number_of_weekly_retention_days" \
                    -exec "${backupRotation_cleanup_command[*]}" {} \;
            fi
            # Clean outdated monthly backups.
            if [ -d "${target_path}/${backupRotation_monthly_target_path}" ]; then
                find \
                    "${target_path}/${backupRotation_monthly_target_path}" \
                    -mtime +"$backupRotation_number_of_monthly_retention_days" \
                    -exec "${backupRotation_cleanup_command[*]}" {} \;
            fi
            [ "$backupRotation_post_run_command" = '' ] || \
                eval "$backupRotation_post_run_command" && \
                successful=true
            if $successful; then
                # shellcheck disable=SC2089
                local message="Source files in \"$source_path\" from node \"$backupRotation_name\" successfully backed up to \"${target_file_path}${backupRotation_target_file_extension}\"."$'\n\nCurrent Backup structure:\n'
                $backupRotation_verbose && \
                    echo -e "$message" && \
                        tree -h -t "$target_path" && \
                            df ./ --human-readable
                if hash msmtp && [[ "$backupRotation_sender_e_mail_address" != '' ]]; then
                    for e_mail_address in \
                        $(echo "${backupRotation_source_target_mappings[$source_path]}" | \
                        grep ' .+$' --only-matching --extended-regexp)
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
                sed "0,/${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}/s/${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}<\\/span>/" | \
                    sed "s/${backupRotation_target_weekly_file_name}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_weekly_file_name}${backupRotation_target_file_extension}<\\/span>/" | \
                        sed "s/${backupRotation_target_monthly_file_name}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_monthly_file_name}${backupRotation_target_file_extension}<\\/span>/"
)
        </pre>
    </p>
    <p><pre>$(df ./ --human-readable)</pre></p>
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
            $backupRotation_verbose && \
                echo -e "$message" &>/dev/stderr && \
                    tree -h -t "$target_path" && \
                        df ./ --human-readable
            if hash msmtp && [[ "$backupRotation_sender_e_mail_address" != '' ]]; then
                local e_mail_address
                for e_mail_address in \
                    $(echo "${backupRotation_source_target_mappings[$source_path]}" | \
                        grep ' .+$' --only-matching --extended-regexp)
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
                sed "0,/${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}/s/${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_daily_file_name}${backupRotation_target_file_extension}<\\/span>/" | \
                    sed "s/${backupRotation_target_weekly_file_name}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_weekly_file_name}${backupRotation_target_file_extension}<\\/span>/" | \
                        sed "s/${backupRotation_target_monthly_file_name}${backupRotation_target_file_extension}/<span style=\"font-weight:bold\">${backupRotation_target_monthly_file_name}${backupRotation_target_file_extension}<\\/span>/"
)
        </pre>
    </p>
    <p><pre>$(df ./ --human-readable)</pre></p>
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
## endregion
# endregion
if bl.tools.is_main; then
    bl.exception.activate
    bl.exception.try {
        backupRotation.main "$@"
    } bl.exception.catch {
        [ -d "$backupRotation_bashlink_path" ] && \
            rm --recursive "$backupRotation_bashlink_path"
        # shellcheck disable=SC2154
        [ -d "$bl_module_remote_module_cache_path" ] && \
            rm --recursive "$bl_module_remote_module_cache_path"
        bl.logging.error "$bl_exception_last_traceback"
    }
    [ -d "$backupRotation_bashlink_path" ] && \
        rm --recursive "$backupRotation_bashlink_path"
    # shellcheck disable=SC2154
    [ -d "$bl_module_remote_module_cache_path" ] && \
        rm --recursive "$bl_module_remote_module_cache_path"
fi
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
