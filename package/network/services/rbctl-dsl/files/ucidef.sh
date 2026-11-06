# ucidef helpers for the rbctl remote xDSL architecture.
#
# Sourced by /etc/board.d/10-rbctl-dsl inside board_detect(), so the
# rbctl-specific board.json vocabulary lives in this package instead of
# polluting base-files for devices without a remote xDSL board.

ucidef_add_rbctl_dsl() {
	local iface="${1:-lan0.500}"

	# Generic modem declaration: consumed natively by config_generate
	# (→ network.dsl with annex/tone/xfer_mode) and by luci-base
	# (network.js reads board.json dsl.modem → DSL tab visibility).
	ucidef_add_vdsl_modem "b" "av" "ptm"

	# rbctl-specific board data. config_generate only looks at the
	# dsl.atmbridge and dsl.modem members, so dsl.rbctl passes through
	# untouched; /etc/uci-defaults/dsl_defaults consumes it on first
	# boot to enrich network.dsl with the daemon-only options.
	json_select_object dsl
		json_select_object rbctl
			json_add_string config_iface "$iface"
		json_select ..
	json_select ..
}

# Declare one default PTM data link (untagged, index 0) in board.json.
# Matches the daemon zero-config behaviour (auto xfer mode + no link
# sections → queue one untagged PTM link at line open). Boards that
# want a specific default link can call this with vid/pbit.
ucidef_add_rbctl_ptm_link() {
	local name="${1:-dsl}"
	local index="${2:-0}"
	local vid="$3"
	local pbit="${4:-0}"

	json_select_object rbctl
		json_select_object links
			json_select_object "$name"
				json_add_string type "ptm"
				json_add_int index "$index"
				[ -n "$vid" ] && json_add_int vid "$vid"
				json_add_int pbit "$pbit"
			json_select ..
		json_select ..
	json_select ..
}
