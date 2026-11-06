#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# region header
# [Project page](https://tsickert.com/backupRotation)

# Copyright Torben Sickert (info["~at~"]tsickert.com) 16.12.2012

# License
# -------

# This library written by Torben Sickert stands under a creative commons naming
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
# NOTE: Shortens this module's scope to "br_*" and "BR_*" names.
BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^backup\.rotation$/br/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^BACKUP_ROTATION$/BR/')
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
declare -gr BR__DOCTEST_SETUP__='
    # Runs before each test: Neutralizes a local "/etc/backupRotation" and
    # replaces the real backup with a simple file creation.
    BR_SOURCE_TARGET_MAPPINGS=()
    BR_SEND_SUCCESS_E_MAILS=true
    BR_SENDER_E_MAIL_ADDRESS=""
    BR_REPLIER_E_MAIL_ADDRESS=""
    BR_DAILY_TARGET_PATH=daily/
    BR_WEEKLY_TARGET_PATH=weekly/
    BR_MONTHLY_TARGET_PATH=monthly/
    BR_TARGET_DAILY_FILE_BASENAME=day
    BR_TARGET_WEEKLY_FILE_BASENAME=week
    BR_TARGET_MONTHLY_FILE_BASENAME=month
    # NOTE: Zero never matches a real day number.
    BR_MONTH_DAY_NUMBER=0
    BR_WEEK_DAY_NUMBER=0
    BR_NUMBER_OF_DAILY_RETENTION_DAYS=14
    BR_NUMBER_OF_WEEKLY_RETENTION_DAYS=56
    BR_NUMBER_OF_MONTHLY_RETENTION_DAYS=365
    BR_TARGET_FILE_EXTENSION=.tar.gz
    BR_COMMAND="touch \"\${target_file_basepath}\${BR_TARGET_FILE_EXTENSION}\""
    BR_ENCRYPT_COMMAND=""
    BR_POST_RUN_COMMAND=""
    BR_CLEANUP_COMMAND="rm --recursive"
    BR_VERBOSE=false
    BR_MONITORING_URL=""
    BR_NAME=test
    # Lists given directory relative to the current one including link targets.
    br_doctest_list() {
        find "$1" \( -type l -printf "%p -> %l\n" \) -o -printf "%p\n" | \
            sed "s:${PWD}/::g" | \
                sort
    }
    # Puts recording "msmtp", "curl" and "tree" mocks in front of "PATH".
    br_doctest_mock_commands() {
        mkdir --parents mock
        printf "#!/usr/bin/env bash\necho \"\$*\" >>\"%s\"\n" \
            "${PWD}/curl.log" \
                >mock/curl
        printf "#!/usr/bin/env bash\ncat >>\"%s\"\n" "${PWD}/msmtp.log" \
            >mock/msmtp
        printf "#!/usr/bin/env bash\necho tree\n" >mock/tree
        chmod +x mock/*
        PATH="${PWD}/mock:${PATH}"
    }
'
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
declare -g BR_TARGET_WEEKLY_FILE_BASENAME="$(date +'%V.week-')${BR_TARGET_DAILY_FILE_BASENAME}"
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

declare -g BR_COMMAND_DEFAULT_ARGUMENTS='--acls --delete --devices --exclude=backup --exclude=done --exclude=log --exclude=migration --exclude=mockup --exclude=node_modules --exclude=preRendered --exclude=readme.md --exclude=.cache --exclude=.git --exclude=.local --exclude=.m2 --exclude=.node-gyp --exclude=.npm --exclude=.ssh --exclude=.yarn --executability --force --group --hard-links --human-readable --itemize-changes --links --max-delete=10000 --owner --perms --progress --protect-args --quiet --recursive --specials --super --times --whole-file'
declare -g BR_COMMAND=''
declare -g BR_ENCRYPT_COMMAND=''
if [ -s /etc/backupRotationPassword ]; then
    # NOTE: Decrypt via batch mode:
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
    BR_COMMAND="rsync $BR_COMMAND_DEFAULT_ARGUMENTS "'"$source_path" "$target_file_basepath" && pushd "$(dirname "$target_file_basepath")" &>/dev/null && tar --create --gzip --file "${target_file_basepath}${BR_TARGET_FILE_BASE_EXTENSION}" "$(basename "$target_file_basepath")"; popd &>/dev/null && rm --recursive "$target_file_basepath"'
fi
## endregion
BL_MODULE_FUNCTION_SCOPE_REWRITES+=('^backupRotation([._][a-zA-Z_-]+)?$/br\1/')
BL_MODULE_GLOBAL_SCOPE_REWRITES+=('^BACKUP_ROTATION(_[a-zA-Z_-]+)?$/BR\1/')
# endregion
# region helper
alias br.get_target_path=br_get_target_path
br_get_target_path() {
    local -r __documentation__='
        Determines the target path from given source target mapping value.

        >>> br.get_target_path "/backup a@b.tld c@d.tld"
        /backup
    '
    local -a parts
    read -r -a parts <<<"$1"
    echo "${parts[0]}"
}
alias br.get_e_mail_addresses=br_get_e_mail_addresses
br_get_e_mail_addresses() {
    local -r __documentation__='
        Lists all e-mail addresses from given source target mapping value.

        >>> br.get_e_mail_addresses "/backup a@b.tld c@d.tld"
        a@b.tld
        c@d.tld

        >>> br.get_e_mail_addresses /backup
    '
    local -a parts
    read -r -a parts <<<"$1"
    if (( ${#parts[@]} > 1 )); then
        printf '%s\n' "${parts[@]:1}"
    fi
}
alias br.get_target_file_basepath=br_get_target_file_basepath
br_get_target_file_basepath() {
    local -r __documentation__='
        Determines the backup file path (without extension) in given target
        path for given month and week day number.

        >>> BR_MONTH_DAY_NUMBER=1
        >>> BR_WEEK_DAY_NUMBER=6
        >>> br.get_target_file_basepath /backup 2 3
        >>> br.get_target_file_basepath /backup 2 6
        >>> br.get_target_file_basepath /backup 1 3
        >>> br.get_target_file_basepath /backup 1 6
        /backup/daily/day
        /backup/weekly/week
        /backup/monthly/month
        /backup/monthly/month
    '
    local -r target_path="$1"
    local -ir month_day_number="$2"
    local -ir week_day_number="$3"
    if (( BR_MONTH_DAY_NUMBER == month_day_number )); then
        echo "${target_path}/${BR_MONTHLY_TARGET_PATH}${BR_TARGET_MONTHLY_FILE_BASENAME}"
    elif (( BR_WEEK_DAY_NUMBER == week_day_number )); then
        echo "${target_path}/${BR_WEEKLY_TARGET_PATH}${BR_TARGET_WEEKLY_FILE_BASENAME}"
    else
        echo "${target_path}/${BR_DAILY_TARGET_PATH}${BR_TARGET_DAILY_FILE_BASENAME}"
    fi
}
alias br.link_backup=br_link_backup
br_link_backup() {
    local -r __documentation__='
        Links a weekly or monthly backup into the daily and (for a monthly
        backup on the configured week day) weekly backups.

        Nothing is linked on a regular day:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br.link_backup "${PWD}/target" 2 3
        >>> [ -e target ] || echo nothing linked
        nothing linked

        A weekly backup is linked into the daily backups:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> BR_MONTH_DAY_NUMBER=1
        >>> BR_WEEK_DAY_NUMBER=6
        >>> br.link_backup "${PWD}/target" 2 6
        >>> br_doctest_list target
        target
        target/daily
        target/daily/day.tar.gz -> target/weekly/week.tar.gz

        A monthly backup is linked into the daily backups:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> BR_MONTH_DAY_NUMBER=1
        >>> BR_WEEK_DAY_NUMBER=6
        >>> br.link_backup "${PWD}/target" 1 3
        >>> br_doctest_list target
        target
        target/daily
        target/daily/day.tar.gz -> target/monthly/month.tar.gz

        A monthly backup on the configured week day is linked into the daily
        and weekly backups:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> BR_MONTH_DAY_NUMBER=1
        >>> BR_WEEK_DAY_NUMBER=6
        >>> br.link_backup "${PWD}/target" 1 6
        >>> br_doctest_list target
        target
        target/daily
        target/daily/day.tar.gz -> target/monthly/month.tar.gz
        target/weekly
        target/weekly/week.tar.gz -> target/monthly/month.tar.gz
    '
    local -r target_path="$1"
    local -ir month_day_number="$2"
    local -ir week_day_number="$3"
    local -r target_file_path="$(
        br.get_target_file_basepath \
            "$target_path" "$month_day_number" "$week_day_number"
    )${BR_TARGET_FILE_EXTENSION}"
    local -a link_target_file_paths=()
    if \
        (( BR_MONTH_DAY_NUMBER == month_day_number )) || \
        (( BR_WEEK_DAY_NUMBER == week_day_number ))
    then
        link_target_file_paths+=("${target_path}/${BR_DAILY_TARGET_PATH}${BR_TARGET_DAILY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}")
    fi
    if \
        (( BR_MONTH_DAY_NUMBER == month_day_number )) && \
        (( BR_WEEK_DAY_NUMBER == week_day_number ))
    then
        link_target_file_paths+=("${target_path}/${BR_WEEKLY_TARGET_PATH}${BR_TARGET_WEEKLY_FILE_BASENAME}${BR_TARGET_FILE_EXTENSION}")
    fi
    local link_target_file_path
    for link_target_file_path in "${link_target_file_paths[@]}"; do
        mkdir --parents "$(dirname "$link_target_file_path")"
        ln \
            --force \
            --symbolic \
            "$target_file_path" \
            "$link_target_file_path"
    done
}
alias br.run_backup=br_run_backup
br_run_backup() {
    local -r __documentation__='
        Runs the configured backup command for given source, target and backup
        file path (without extension). The configured command can reference
        them as "$source_path", "$target_path" and "$target_file_basepath".

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> BR_COMMAND+=";"
        >>> local -r command="$BR_COMMAND"
        >>> br.run_backup "${PWD}/source" "${PWD}/target" "${PWD}/target/daily/day"
        >>> br_doctest_list target
        >>> [[ "$BR_COMMAND" == "$command" ]] && echo unchanged
        target
        target/daily
        target/daily/day.tar.gz
        unchanged

        >>> BR_COMMAND="echo output; false"
        >>> br.run_backup source target target/daily/day; echo $?
        1
    '
    local -r source_path="$1"
    local -r target_path="$2"
    local -r target_file_basepath="$3"
    mkdir --parents "$(dirname "$target_file_basepath")"
    local command="$BR_COMMAND"
    if bl.logging.is_enabled info; then
        echo "Running \"${command}\"."
    else
        # NOTE: The newline terminates a trailing "&" or ";" in the
        # configured command.
        command="{ ${command}"$'\n'"} &>/dev/null"
    fi
    eval "$command" || return $?
    sync
}
alias br.encrypt_backup=br_encrypt_backup
br_encrypt_backup() {
    local -r __documentation__='
        Runs the configured encryption command (if any) for given backup file
        path (without extension) which can be referenced as
        "$target_file_basepath".

        >>> br.encrypt_backup target/daily/day; echo $?
        0

        >>> BR_ENCRYPT_COMMAND="echo \"\$target_file_basepath\""
        >>> br.encrypt_backup target/daily/day
        target/daily/day

        >>> BR_ENCRYPT_COMMAND=false
        >>> br.encrypt_backup target/daily/day; echo $?
        1
    '
    local -r target_file_basepath="$1"
    local -i result=0
    if [[ "$BR_ENCRYPT_COMMAND" != '' ]] && ! eval "$BR_ENCRYPT_COMMAND"; then
        result=1
    fi
    sync
    return $result
}
alias br.clean_outdated_backups=br_clean_outdated_backups
br_clean_outdated_backups() {
    local -r __documentation__='
        Removes daily, weekly and monthly backups in given target path which
        are older than their configured retention days and lists them.

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> mkdir --parents target/daily target/weekly target/monthly
        >>> touch --date="-15 days" target/daily/outdated.tar.gz
        >>> touch --date="-13 days" target/daily/current.tar.gz
        >>> touch --date="-57 days" target/weekly/outdated.tar.gz
        >>> touch --date="-366 days" target/monthly/outdated.tar.gz
        >>> br.clean_outdated_backups "${PWD}/target" | sed "s:${PWD}/::"
        >>> br_doctest_list target
        target/daily/outdated.tar.gz
        target/weekly/outdated.tar.gz
        target/monthly/outdated.tar.gz
        target
        target/daily
        target/daily/current.tar.gz
        target/monthly
        target/weekly

        Missing directories are skipped:

        >>> br.clean_outdated_backups /not/existing; echo $?
        0
    '
    local -r target_path="$1"
    local period
    for period in daily weekly monthly; do
        local path_name="BR_${period^^}_TARGET_PATH"
        local retention_days_name="BR_NUMBER_OF_${period^^}_RETENTION_DAYS"
        local path="${target_path}/${!path_name}"
        if [ -d "$path" ]; then
            bl.logging.info "Clearing old ${period} backups in \"${path}\":"
            find "$path" -mtime +"${!retention_days_name}"
            # shellcheck disable=SC2086
            find \
                "$path" \
                -mtime +"${!retention_days_name}" \
                -exec $BR_CLEANUP_COMMAND {} \;
        fi
    done
}
alias br.get_message=br_get_message
br_get_message() {
    local -r __documentation__='
        Creates the report message for given source, backup file path (without
        extension), backup result and optional post run command result. Line
        breaks are encoded as "\n".

        >>> br.get_message /source /backup/daily/day true
        Source files in "/source" from node "test" successfully backed up to "/backup/daily/day.tar.gz".\n\nCurrent Backup structure:\n

        >>> br.get_message /source /backup/daily/day false
        Source files in "/source" from node "test" should be backed up but has failed.\n\nCurrent Backup structure:\n

        >>> br.get_message /source /backup/daily/day true true
        +bl.doctest.contains
        \n\nPost run command was successful.\n\n

        >>> br.get_message /source /backup/daily/day true false
        +bl.doctest.contains
        \n\nPost run command was not successful!\n\n
    '
    local -r source_path="$1"
    local -r target_file_basepath="$2"
    local -r successful="$3"
    local -r post_run_successful="${4:-}"
    local message="Source files in \"${source_path}\" from node \"${BR_NAME}\" "
    if $successful; then
        message+="successfully backed up to \"${target_file_basepath}${BR_TARGET_FILE_EXTENSION}\"."
    else
        message+='should be backed up but has failed.'
    fi
    if [[ "$post_run_successful" == true ]]; then
        message+='\n\nPost run command was successful.'
    elif [[ "$post_run_successful" == false ]]; then
        message+='\n\nPost run command was not successful!'
    fi
    message+='\n\nCurrent Backup structure:\n'
    echo "$message"
}
alias br.send_e_mail=br_send_e_mail
br_send_e_mail() {
    local -r __documentation__='
        Sends given message with the current backup structure of given target
        path to given e-mail address.

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> br.send_e_mail a@b.tld "$PWD" "Saved \"/source\"." true
        >>> grep --extended-regexp "^(From|To|Subject):|/source" msmtp.log
        From: sender@b.tld
        To: a@b.tld
        Subject: Backup was successful
            <p>Saved "<span style="font-weight:bold">/source</span>".</p>

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> br.send_e_mail a@b.tld "$PWD" message false
        >>> grep "^Subject:" msmtp.log
        Subject: Backup has failed
    '
    local -r e_mail_address="$1"
    local -r target_path="$2"
    local -r message="$3"
    local -r successful="$4"
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
}
alias br.notify=br_notify
br_notify() {
    local -r __documentation__='
        Sends given message to all recipients of given source and informs the
        monitoring service about the result. Success e-mails can be disabled
        via "BR_SEND_SUCCESS_E_MAILS".

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(["/source"]="${PWD} a@b.tld c@d.tld")
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> BR_MONITORING_URL=https://monitoring.tld
        >>> br.notify /source "$PWD" message true
        >>> grep "^To:" msmtp.log
        >>> sed "s:${PWD}:/target:" curl.log
        To: a@b.tld
        To: c@d.tld
        --data {"source": "/source", "target": "/target", "error": false} --header Content-Type: application/json --request PUT https://monitoring.tld

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(["/source"]="${PWD} a@b.tld")
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> BR_SEND_SUCCESS_E_MAILS=false
        >>> br.notify /source "$PWD" message true
        >>> [ -f msmtp.log ] || echo no e-mail
        >>> br.notify /source "$PWD" message false
        >>> grep "^Subject:" msmtp.log
        no e-mail
        Subject: Backup has failed

        The monitoring service is informed independently of e-mails. No
        e-mail is sent without a sender address:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(["/source"]="${PWD} a@b.tld")
        >>> BR_MONITORING_URL=https://monitoring.tld
        >>> br.notify /source "$PWD" message false
        >>> [ -f msmtp.log ] || echo no e-mail
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> BR_SEND_SUCCESS_E_MAILS=false
        >>> br.notify /source "$PWD" message true
        >>> [ -f msmtp.log ] || echo no e-mail
        >>> grep --only-matching "\"error\": [a-z]*" curl.log
        no e-mail
        no e-mail
        "error": true
        "error": false
    '
    local -r source_path="$1"
    local -r target_path="$2"
    local -r message="$3"
    local -r successful="$4"
    if \
        ( ! $successful || $BR_SEND_SUCCESS_E_MAILS ) && \
        [[ "$BR_SENDER_E_MAIL_ADDRESS" != '' ]] && \
        hash msmtp
    then
        local e_mail_address
        for e_mail_address in $(
            br.get_e_mail_addresses "${BR_SOURCE_TARGET_MAPPINGS[$source_path]}"
        ); do
            br.send_e_mail \
                "$e_mail_address" "$target_path" "$message" "$successful"
        done
    fi
    if [[ "$BR_MONITORING_URL" != '' ]]; then
        local error=true
        if $successful; then
            error=false
        fi
        curl \
            --data "{\"source\": \"$source_path\", \"target\": \"$target_path\", \"error\": ${error}}" \
            --header 'Content-Type: application/json' \
            --request PUT \
            "$BR_MONITORING_URL"
    fi
}
# endregion
# region controller
alias br.main=br_main
br_main() {
    local -r __documentation__='
        Backs up each source of "BR_SOURCE_TARGET_MAPPINGS" into its target,
        rotates outdated backups and notifies configured recipients.

        Each mapping is backed up exactly once:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> BR_SOURCE_TARGET_MAPPINGS=(
        >>>     ["${PWD}/source1"]="${PWD}/target1"
        >>>     ["${PWD}/source2"]="${PWD}/target2"
        >>> )
        >>> BR_COMMAND="echo \"\$source_path\" >>runs.log; ${BR_COMMAND}"
        >>> br.main
        >>> sed "s:${PWD}/::" runs.log | sort
        >>> br_doctest_list target1
        source1
        source2
        target1
        target1/daily
        target1/daily/day.tar.gz

        A failing backup keeps outdated backups, skips the post run command
        and is reported:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(["${PWD}/source"]="${PWD}/target a@b.tld")
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> BR_SEND_SUCCESS_E_MAILS=false
        >>> BR_MONITORING_URL=https://monitoring.tld
        >>> BR_COMMAND=false
        >>> BR_POST_RUN_COMMAND="echo executed >post-run.log"
        >>> mkdir --parents target/daily
        >>> touch --date="-15 days" target/daily/outdated.tar.gz
        >>> br.main
        >>> br_doctest_list target
        >>> [ -f post-run.log ] || echo not executed
        >>> grep "^Subject:" msmtp.log
        >>> grep --count "should be backed up but has failed." msmtp.log
        >>> grep --only-matching "\"error\": [a-z]*" curl.log
        target
        target/daily
        target/daily/outdated.tar.gz
        not executed
        Subject: Backup has failed
        1
        "error": true

        A successful backup is reported to each recipient:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(
        >>>     ["${PWD}/source"]="${PWD}/target a@b.tld c@d.tld"
        >>> )
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> br.main
        >>> grep --extended-regexp "^(To|Subject):" msmtp.log
        >>> grep --count "successfully backed up to" msmtp.log
        To: a@b.tld
        Subject: Backup was successful
        To: c@d.tld
        Subject: Backup was successful
        2

        A failing encryption is reported:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(["${PWD}/source"]="${PWD}/target a@b.tld")
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> BR_ENCRYPT_COMMAND=false
        >>> br.main
        >>> grep "^Subject:" msmtp.log
        >>> grep --count "should be backed up but has failed." msmtp.log
        Subject: Backup has failed
        1

        A post run command is only executed after a successful backup and its
        result is reported:

        >>> cd "$(br_bl_doctest_mktemp --directory)"
        >>> br_doctest_mock_commands
        >>> BR_SOURCE_TARGET_MAPPINGS=(["${PWD}/source"]="${PWD}/target a@b.tld")
        >>> BR_SENDER_E_MAIL_ADDRESS=sender@b.tld
        >>> BR_POST_RUN_COMMAND=true
        >>> br.main
        >>> BR_POST_RUN_COMMAND=false
        >>> br.main
        >>> BR_ENCRYPT_COMMAND=false
        >>> BR_POST_RUN_COMMAND="echo executed >post-run.log"
        >>> br.main
        >>> grep --extended-regexp "^Subject:|Post run command" msmtp.log
        >>> [ -f post-run.log ] || echo not executed
        Subject: Backup was successful
        Post run command was successful.
        Subject: Backup has failed
        Post run command was not successful!
        Subject: Backup has failed
        not executed
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
            br.get_target_path "${BR_SOURCE_TARGET_MAPPINGS[$source_path]}"
        )"
        local target_file_basepath="$(
            br.get_target_file_basepath \
                "$target_path" "$month_day_number" "$week_day_number"
        )"
        br.link_backup "$target_path" "$month_day_number" "$week_day_number"
        local successful=false
        # NOTE: Outdated backups are only removed after a successful backup
        # run.
        if br.run_backup "$source_path" "$target_path" "$target_file_basepath"
        then
            if br.encrypt_backup "$target_file_basepath"; then
                successful=true
            fi
            br.clean_outdated_backups "$target_path"
        fi
        local post_run_successful=''
        if $successful && [[ "$BR_POST_RUN_COMMAND" != '' ]]; then
            if eval "$BR_POST_RUN_COMMAND"; then
                post_run_successful=true
            else
                post_run_successful=false
            fi
        fi
        local message="$(
            br.get_message \
                "$source_path" \
                "$target_file_basepath" \
                "$successful" \
                "$post_run_successful"
        )"
        if [[ "$post_run_successful" == false ]]; then
            successful=false
        fi
        if bl.logging.is_enabled info; then
            echo -e "$message"
            tree -h -t "$target_path"
            du --human-readable --summarize "$target_path"
            df ./ --human-readable
        fi
        br.notify "$source_path" "$target_path" "$message" "$successful"
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
