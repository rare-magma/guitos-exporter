#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(curl date gzip jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

source "./guitos_exporter.conf"

[[ -z "${INFLUXDB_HOST}" ]] && echo >&2 "INFLUXDB_HOST is empty. Aborting" && exit 1
[[ -z "${INFLUXDB_API_TOKEN}" ]] && echo >&2 "INFLUXDB_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${ORG}" ]] && echo >&2 "ORG is empty. Aborting" && exit 1
[[ -z "${BUCKET}" ]] && echo >&2 "BUCKET is empty. Aborting" && exit 1
[[ ! -f "${1}" ]] && echo >&2 "First argument is not a file. Aborting" && exit 1

CURL=$(command -v curl)
DATE=$(command -v date)
GZIP=$(command -v gzip)
JQ=$(command -v jq)

INFLUXDB_URL="https://$INFLUXDB_HOST/api/v2/write?precision=s&org=$ORG&bucket=$BUCKET"
BUDGET_FIELDS=".name,.expenses.total,.incomes.total,.stats.available,.stats.withGoal,.stats.saved,.stats.goal,.stats.reserves"

length=$($JQ 'length - 1' "$1")

for i in $(seq 0 "$length"); do

    mapfile -t parsed_budget < <($JQ --raw-output ".[$i] | $BUDGET_FIELDS" "$1")
    name=${parsed_budget[0]}
    expenses=${parsed_budget[1]}
    revenue=${parsed_budget[2]}
    available=${parsed_budget[3]}
    with_goal=${parsed_budget[4]}
    saved=${parsed_budget[5]}
    goal=${parsed_budget[6]}
    reserves=${parsed_budget[7]}
    ts=$($DATE "+%s" --date="${name}-02")

    budget_stats+=$(
        printf "\nguitos,period=%s expenses=%s,revenue=%s,available=%s,with_goal=%s,saved=%s,goal=%s,reserves=%s %s" \
            "$name" "$expenses" "$revenue" "$available" "$with_goal" "$saved" "$goal" "$reserves" "$ts"
    )
done

echo "$budget_stats" | $GZIP |
    $CURL --silent --fail --show-error \
        --request POST "${INFLUXDB_URL}" \
        --header 'Content-Encoding: gzip' \
        --header "Authorization: Token $INFLUXDB_API_TOKEN" \
        --header "Content-Type: text/plain; charset=utf-8" \
        --header "Accept: application/json" \
        --data-binary @-
