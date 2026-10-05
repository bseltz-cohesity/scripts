#!/usr/bin/env bash
#
# epicGflagRecommendations.sh
#
# Calculates recommended Cohesity cluster and agent gflag settings for tuning
# EPIC Cache/IRIS (physical Linux/AIX) backup performance.
#
# Replaces the "Auto tuning Gflags for epic backups for linux_AIX physical.xlsx"
# spreadsheet. Given the same inputs the spreadsheet collected, this script
# computes the same recommended gflag values, prints them to the screen, and
# writes them - along with the exact commands to apply them - to a text file.
#
# Cluster-level gflags are applied with iris_cli. Agent-level gflags are
# applied with magneto_agent_debug_tool, run from an SSH session on the
# Cohesity cluster. AIX env.sh settings must be hand-edited on the mount host
# and the agent restarted.
#
# Usage:
#   ./epicGflagRecommendations.sh --node-count 19 --host-os AIX --nic-speed 10GbE --cpu-cores 20
#   ./epicGflagRecommendations.sh -n 19 -o AIX -s 10GbE -c 20
#
#   ./epicGflagRecommendations.sh --node-count 8 --host-os LINUX --nic-speed ">10GbE" \
#       --cpu-cores 32 --agent-endpoint epic-mount01.hospital.local \
#       --output-file /tmp/epic01-gflags.txt
#   ./epicGflagRecommendations.sh -n 8 -o LINUX -s ">10GbE" -c 32 -a epic-mount01.hospital.local \
#       -f /tmp/epic01-gflags.txt
#
# Author: Brian Seltzer / Cohesity
# Ported from: Auto tuning Gflags for epic backups for linux_AIX physical.xlsx
#
set -u

# ------------------------------------------------------------------------
# Usage / help
# ------------------------------------------------------------------------
usage() {
    cat <<'EOF'
Usage: epicGflagRecommendations.sh -n <count> -o <AIX|LINUX> [options]

Required:
  -n, --node-count <1-256>       Number of nodes in the Cohesity cluster.
  -o, --host-os <AIX|LINUX>      Operating system of the EPIC mount host.

Optional:
  -s, --nic-speed <10GbE|>10GbE> Mount host NIC speed range. Default: >10GbE
  -c, --cpu-cores <1-1024>       Number of CPU cores on the mount host. Default: 24
  -a, --agent-endpoint <host>    Hostname/IP of the mount host, substituted into the
                                 agent CLI commands. Default: a placeholder you can
                                 fill in later if you don't have it handy.
  -f, --output-file <path>       Path to the text file the full recommendations,
                                 apply instructions, and ready-to-paste
                                 command/config sections are written to.
                                 Default: ./EpicGflagRecommendations.txt
  -h, --help                     Show this help and exit.
EOF
}

# ------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------
NODE_COUNT=""
HOST_OS=""
NIC_SPEED=">10GbE"
CPU_CORES=24
AGENT_ENDPOINT="<replace with your hostname or IP>"
OUTPUT_FILE="./EpicGflagRecommendations.txt"

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--node-count)
            NODE_COUNT="${2:-}"; shift 2 ;;
        -o|--host-os)
            HOST_OS="${2:-}"; shift 2 ;;
        -s|--nic-speed)
            NIC_SPEED="${2:-}"; shift 2 ;;
        -c|--cpu-cores)
            CPU_CORES="${2:-}"; shift 2 ;;
        -a|--agent-endpoint)
            AGENT_ENDPOINT="${2:-}"; shift 2 ;;
        -f|--output-file)
            OUTPUT_FILE="${2:-}"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1 ;;
    esac
done

# ------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------
if [ -z "$NODE_COUNT" ] || [ -z "$HOST_OS" ]; then
    echo "Error: --node-count and --host-os are required." >&2
    usage
    exit 1
fi

if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ] || [ "$NODE_COUNT" -gt 256 ]; then
    echo "Error: --node-count must be an integer between 1 and 256." >&2
    exit 1
fi

if ! [[ "$CPU_CORES" =~ ^[0-9]+$ ]] || [ "$CPU_CORES" -lt 1 ] || [ "$CPU_CORES" -gt 1024 ]; then
    echo "Error: --cpu-cores must be an integer between 1 and 1024." >&2
    exit 1
fi

HOST_OS_UPPER=$(printf '%s' "$HOST_OS" | tr '[:lower:]' '[:upper:]')
if [ "$HOST_OS_UPPER" != "AIX" ] && [ "$HOST_OS_UPPER" != "LINUX" ]; then
    echo "Error: --host-os must be AIX or LINUX." >&2
    exit 1
fi

if [ "$NIC_SPEED" != "10GbE" ] && [ "$NIC_SPEED" != ">10GbE" ]; then
    echo "Error: --nic-speed must be '10GbE' or '>10GbE'." >&2
    exit 1
fi

# ------------------------------------------------------------------------
# Helper: Excel's ROUND() rounds half-away-from-zero. This mirrors that,
# rather than relying on whatever rounding mode awk/bc default to.
# ------------------------------------------------------------------------
excel_round_div() {
    # $1 numerator, $2 denominator -> prints rounded integer result
    awk -v num="$1" -v den="$2" 'BEGIN {
        n = num / den
        if (n >= 0) printf "%d", int(n + 0.5)
        else printf "%d", int(n - 0.5)
    }'
}

max2() {
    if [ "$1" -gt "$2" ]; then echo "$1"; else echo "$2"; fi
}

# ------------------------------------------------------------------------
# Core calculations (mirrors the spreadsheet's "DO NOT EDIT" calc table)
# ------------------------------------------------------------------------
IS_TEN_GIG=false
[ "$NIC_SPEED" = "10GbE" ] && IS_TEN_GIG=true

if [ "$HOST_OS_UPPER" = "AIX" ]; then
    AGENT_CONFIG_FILE_PATH="/etc/aix_agent_config.cfg"
else
    AGENT_CONFIG_FILE_PATH="/etc/cohesity-agent/agent.cfg"
fi

if [ "$IS_TEN_GIG" = true ]; then
    GATEKEEPER_VALUE=12
    MEM_SIZE_MB=2048
else
    GATEKEEPER_VALUE=16
    MEM_SIZE_MB=4096
fi

if [ "$HOST_OS_UPPER" = "AIX" ]; then
    GATEKEEPER_FLAG_NAME="magneto_gatekeeper_max_tasks_per_physical_aix_entity"
else
    GATEKEEPER_FLAG_NAME="magneto_gatekeeper_max_tasks_per_physical_linux_entity"
fi

CONCURRENT_SUB_TASKS=$(( 2 * GATEKEEPER_VALUE ))
SUB_TASK_MULTIPLIER=$(max2 "$(excel_round_div "$CONCURRENT_SUB_TASKS" "$NODE_COUNT")" 2)
FILE_RESTORE_MAX=$CONCURRENT_SUB_TASKS
FILE_RESTORE_MULTIPLIER=$SUB_TASK_MULTIPLIER

GRPC_DEFAULT_CQ=$(max2 "$(excel_round_div "$CPU_CORES" 4)" 1)

# ------------------------------------------------------------------------
# Recommendations list - each record is stored as one array element with
# fields joined by a unit-separator character (0x1F), since none of our
# field values can ever contain it.
# ------------------------------------------------------------------------
FS=$'\x1f'
RECS=()

add_rec() {
    # $1 FlagType  $2 ServiceName  $3 FlagName  $4 Value  $5 DefaultValue  $6 Notes  $7 Command
    RECS+=("$1$FS$2$FS$3$FS$4$FS$5$FS$6$FS$7")
}

cluster_cmd() {
    # $1 Service  $2 Flag  $3 Value
    printf 'iris_cli cluster update-gflag service-name=%s gflag-name=%s gflag-value=%s reason="Increasing Parallelism for EPIC Backup" effective-now=true' "$1" "$2" "$3"
}

agent_cmd() {
    # $1 Flag  $2 Value
    printf './magneto_agent_debug_tool update-gflag-settings --agent_gflag_settings=%s:%s --agent_endpoints=%s --agent_gflag_settings_effective_now=true' "$1" "$2" "$AGENT_ENDPOINT"
}

# --- Cluster gflags (magneto) ---
add_rec "Cluster" "magneto" "$GATEKEEPER_FLAG_NAME" "$GATEKEEPER_VALUE" "4" \
    "If host/NIC is >10GbE use 16, else use 12" \
    "$(cluster_cmd magneto "$GATEKEEPER_FLAG_NAME" "$GATEKEEPER_VALUE")"

add_rec "Cluster" "magneto" "magneto_slave_nas_max_concurrent_sub_tasks" "$CONCURRENT_SUB_TASKS" "12" \
    "2x the gatekeeper value" \
    "$(cluster_cmd magneto magneto_slave_nas_max_concurrent_sub_tasks "$CONCURRENT_SUB_TASKS")"

add_rec "Cluster" "magneto" "magneto_slave_nas_concurrent_sub_tasks_multiplier" "$SUB_TASK_MULTIPLIER" "2" \
    "Max of (concurrent sub tasks / node count), 2" \
    "$(cluster_cmd magneto magneto_slave_nas_concurrent_sub_tasks_multiplier "$SUB_TASK_MULTIPLIER")"

add_rec "Cluster" "magneto" "magneto_slave_file_restore_max_concurrent_sub_tasks" "$FILE_RESTORE_MAX" "12" \
    "Same as concurrent sub tasks" \
    "$(cluster_cmd magneto magneto_slave_file_restore_max_concurrent_sub_tasks "$FILE_RESTORE_MAX")"

add_rec "Cluster" "magneto" "magneto_slave_file_restore_concurrent_sub_tasks_multiplier" "$FILE_RESTORE_MULTIPLIER" "2" \
    "Same as sub tasks multiplier" \
    "$(cluster_cmd magneto magneto_slave_file_restore_concurrent_sub_tasks_multiplier "$FILE_RESTORE_MULTIPLIER")"

if [ "$HOST_OS_UPPER" = "AIX" ]; then
    add_rec "Cluster" "magneto" "magneto_java_agent_send_terminate_rpc" "true" "false" \
        "Overcomes a memory leak that slows down ingest over time on AIX" \
        "$(cluster_cmd magneto magneto_java_agent_send_terminate_rpc true)"
fi

add_rec "Cluster" "bridge_proxy" "bridge_magneto_skip_local_ip_get" "true" "false" \
    "Skips a local IP lookup that can slow ingest on some network setups" \
    "$(cluster_cmd bridge_proxy bridge_magneto_skip_local_ip_get true)"

# --- Agent gflags: Linux ---
if [ "$HOST_OS_UPPER" = "LINUX" ]; then
    add_rec "Agent" "/etc/cohesity-agent/agent.cfg" "max_rpc_context_count" "32" "16" \
        "Static starting recommendation; helps primarily restores" \
        "$(agent_cmd max_rpc_context_count 32)"

    add_rec "Agent" "/etc/cohesity-agent/agent.cfg" "grpc_server_cq_control_threads" "2" "1" \
        "6.8.1_u2 and later only" \
        "$(agent_cmd grpc_server_cq_control_threads 2)"

    add_rec "Agent" "/etc/cohesity-agent/agent.cfg" "grpc_server_cq_data_threads" "2" "1" \
        "6.8.1_u2 and later only" \
        "$(agent_cmd grpc_server_cq_data_threads 2)"

    add_rec "Agent" "/etc/cohesity-agent/agent.cfg" "grpc_number_of_default_cq" "$GRPC_DEFAULT_CQ" "1" \
        "CPU cores / 4 (min 1); 6.8.1_u2 and later only" \
        "$(agent_cmd grpc_number_of_default_cq "$GRPC_DEFAULT_CQ")"
fi

# --- Agent gflags: AIX ---
ENV_SH_LINES=()
if [ "$HOST_OS_UPPER" = "AIX" ]; then
    add_rec "Agent" "/etc/aix_agent_config.cfg" "JavaAgentTerminateForcefully" "true" "false" \
        "Overcomes a memory leak that slows down ingest over time on AIX" \
        "$(agent_cmd JavaAgentTerminateForcefully true)"

    add_rec "Agent" "/etc/aix_agent_config.cfg" "StorageProxyMaxBrickReadSize" "2097152" "Unknown" \
        "Static recommendation for AIX EPIC backup tuning" \
        "$(agent_cmd StorageProxyMaxBrickReadSize 2097152)"

    add_rec "Agent" "/etc/aix_agent_config.cfg" "JavaAgentGrpcThreadpoolSize" "128" "32" \
        "Static starting recommendation; 6.8.1_u2 and later only. Revisit if AIX host CPU/load is unusually high or low" \
        "$(agent_cmd JavaAgentGrpcThreadpoolSize 128)"

    # --- env.sh settings (AIX only, hand-edited - no CLI command) ---
    XMX_LINE="COHESITY_AGENT_XMX=\"\${COHESITY_AGENT_XMX:--Xmx${MEM_SIZE_MB}m}\""
    add_rec "env.sh" "/usr/local/cohesity/set_env.sh" "COHESITY_AGENT_XMX" "${MEM_SIZE_MB}m" "1024m" \
        "Can be tweaked higher depending on available server memory" \
        "Edit /usr/local/cohesity/set_env.sh and set: ${XMX_LINE}"

    MAXDIRECT_LINE="COHESITY_AGENT_MAX_DIRECT_MEMORY_SIZE=\"\${COHESITY_AGENT_MAX_DIRECT_MEMORY_SIZE:--XX:MaxDirectMemorySize=${MEM_SIZE_MB}m}\""
    add_rec "env.sh" "/usr/local/cohesity/set_env.sh" "COHESITY_AGENT_MAX_DIRECT_MEMORY_SIZE" "${MEM_SIZE_MB}m" "1024m" \
        "Can be tweaked higher depending on available server memory" \
        "Edit /usr/local/cohesity/set_env.sh and set: ${MAXDIRECT_LINE}"

    ENV_SH_LINES=("$XMX_LINE" "$MAXDIRECT_LINE")
fi

# ------------------------------------------------------------------------
# Agent config file stanza (/etc/aix_agent_config.cfg on AIX, or
# /etc/cohesity-agent/agent.cfg on Linux) - built from the agent
# recommendations above, in the user_settings/gflag_setting_vec format the
# file expects. This is an alternative to magneto_agent_debug_tool.
# ------------------------------------------------------------------------
STANZA=()
STANZA+=("user_settings {")
for rec in "${RECS[@]}"; do
    IFS="$FS" read -r ft svc fn val def notes cmd <<< "$rec"
    if [ "$ft" = "Agent" ]; then
        STANZA+=("  gflag_setting_vec {")
        STANZA+=("    name: \"$fn\"")
        STANZA+=("    value: \"$val\"")
        STANZA+=("  }")
    fi
done
STANZA+=("}")

# ------------------------------------------------------------------------
# Agent restart commands - needed after editing the agent config file
# directly or (on AIX) after editing set_env.sh.
# ------------------------------------------------------------------------
if [ "$HOST_OS_UPPER" = "AIX" ]; then
    RESTART_CMDS=(
        "/usr/local/cohesity/agent/aix_agent.sh stop"
        "/usr/local/cohesity/agent/aix_agent.sh start"
        "/usr/local/cohesity/agent/aix_agent.sh status"
    )
else
    RESTART_CMDS=(
        "sudo systemctl restart cohesity-agent"
        "sudo systemctl status cohesity-agent"
    )
fi

# ------------------------------------------------------------------------
# Screen output
# ------------------------------------------------------------------------
echo
echo "=== EPIC Cache/IRIS gflag Recommendations ==="
echo "Nodes: $NODE_COUNT | Host OS: $HOST_OS_UPPER | NIC Speed: $NIC_SPEED | CPU Cores: $CPU_CORES"
echo

printf "%-8s %-32s %-58s %-8s %-8s\n" "FlagType" "ServiceName" "FlagName" "Value" "Default"
for rec in "${RECS[@]}"; do
    IFS="$FS" read -r ft svc fn val def notes cmd <<< "$rec"
    printf "%-8s %-32s %-58s %-8s %-8s\n" "$ft" "$svc" "$fn" "$val" "$def"
done
echo

echo "--- Commands to apply (copy/paste) ---"
for rec in "${RECS[@]}"; do
    IFS="$FS" read -r ft svc fn val def notes cmd <<< "$rec"
    echo
    echo "# $fn -> $val  ($notes)"
    echo "$cmd"
done
echo

echo "--- Alternative: $AGENT_CONFIG_FILE_PATH stanza (append if new, merge if user_settings already exists) ---"
for stanzaLine in "${STANZA[@]}"; do
    echo "$stanzaLine"
done
echo

# ------------------------------------------------------------------------
# File output - full recommendations + instructions
# ------------------------------------------------------------------------
LINES=()
add_line() { LINES+=("$1"); }

add_line "EPIC Cache/IRIS gflag Recommendations for Linux/AIX Physical Mount Hosts"
add_line "Generated: $(date "+%Y-%m-%d %H:%M:%S")"
add_line ""
add_line "Inputs"
add_line "------"
add_line "Number of nodes in Cohesity cluster : $NODE_COUNT"
add_line "Mount host operating system         : $HOST_OS_UPPER"
add_line "Mount host NIC speed range           : $NIC_SPEED"
add_line "Mount host CPU cores                : $CPU_CORES"
add_line ""
add_line "How to apply these settings"
add_line "----------------------------"
add_line "1. Cluster gflags: run the iris_cli commands below from any CVM (or via SSH to the cluster VIP)."
add_line "   A paste-ready version of these commands, with the leading 'iris_cli' stripped off so they can"
add_line "   be pasted directly into an already-open iris_cli session, is included below."
add_line "2. Agent gflags: run the magneto_agent_debug_tool commands below from an SSH session on the Cohesity"
add_line "   cluster - replace the placeholder with the actual mount host hostname/IP if you did not pass"
add_line "   -a/--agent-endpoint."
add_line "2a. Agent gflags - alternative to magneto_agent_debug_tool: edit $AGENT_CONFIG_FILE_PATH on the mount"
add_line "    host directly and add the stanza shown below."
add_line "    - If the file does NOT already contain a user_settings stanza, append the whole block to the"
add_line "      end of the file."
add_line "    - If a user_settings stanza already exists, merge each gflag_setting_vec entry into the"
add_line "      existing stanza instead of adding a second one - the agent only reads the first"
add_line "      user_settings block. Update the value if an entry with the same name is already present,"
add_line "      otherwise add a new gflag_setting_vec entry for it."
add_line "    - Restart the Cohesity agent after editing (see 'Restarting the Cohesity Agent' below)."
add_line "3. env.sh settings (AIX only): manually edit /usr/local/cohesity/set_env.sh on the mount host and"
add_line "   update the two existing settings shown below, then restart the Cohesity agent (see"
add_line "   'Restarting the Cohesity Agent' below)."
add_line "4. After applying, kick off a test backup and monitor throughput before rolling out further."
add_line ""
add_line "Recommended Settings"
add_line "---------------------"

for rec in "${RECS[@]}"; do
    IFS="$FS" read -r ft svc fn val def notes cmd <<< "$rec"
    add_line ""
    add_line "[$ft] $svc -> $fn"
    add_line "  Recommended value : $val"
    add_line "  Default value     : $def"
    add_line "  Notes             : $notes"
    add_line "  Command           : $cmd"
done

add_line ""
add_line "Cluster iris_cli Commands (paste-ready)"
add_line "----------------------------------------"
add_line "Leading 'iris_cli' stripped off so these can be pasted directly into an already-open iris_cli"
add_line "session, one line at a time."
add_line ""
for rec in "${RECS[@]}"; do
    IFS="$FS" read -r ft svc fn val def notes cmd <<< "$rec"
    if [ "$ft" = "Cluster" ]; then
        add_line "${cmd#iris_cli }"
    fi
done

add_line ""
add_line "Agent magneto_agent_debug_tool Commands (paste-ready)"
add_line "-------------------------------------------------------"
add_line "Run from an SSH session on the Cohesity cluster. Replace the placeholder with the actual mount"
add_line "host hostname/IP if you did not pass -a/--agent-endpoint."
add_line ""
for rec in "${RECS[@]}"; do
    IFS="$FS" read -r ft svc fn val def notes cmd <<< "$rec"
    if [ "$ft" = "Agent" ]; then
        add_line "$cmd"
    fi
done

add_line ""
add_line "Agent Config File Stanza ($AGENT_CONFIG_FILE_PATH)"
add_line "---------------------------------------------------"
add_line "Alternative to magneto_agent_debug_tool for the agent gflags above. Append this block if"
add_line "$AGENT_CONFIG_FILE_PATH has no user_settings stanza yet, or merge the gflag_setting_vec"
add_line "entries into the existing stanza if one is already present (do not create a second one)."
add_line ""
for stanzaLine in "${STANZA[@]}"; do
    add_line "$stanzaLine"
done

if [ "$HOST_OS_UPPER" = "AIX" ]; then
    add_line ""
    add_line "env.sh Settings (/usr/local/cohesity/set_env.sh)"
    add_line "---------------------------------------------------"
    add_line "AIX only. These settings already exist in /usr/local/cohesity/set_env.sh on the mount host -"
    add_line "edit the file and update the existing values for the two lines below. Restart the Cohesity"
    add_line "agent after editing (see 'Restarting the Cohesity Agent' below)."
    add_line ""
    for envLine in "${ENV_SH_LINES[@]}"; do
        add_line "$envLine"
    done
fi

add_line ""
add_line "Restarting the Cohesity Agent"
add_line "------------------------------"
add_line "Run on the mount host after editing $AGENT_CONFIG_FILE_PATH or set_env.sh:"
add_line ""
for restartCmd in "${RESTART_CMDS[@]}"; do
    add_line "$restartCmd"
done

add_line ""
add_line "Questions or suggestions: contact Brian Seltzer or Adaikkappan Arumugam."

printf '%s\n' "${LINES[@]}" > "$OUTPUT_FILE"

echo "Recommendations written to: $OUTPUT_FILE"
