#!/usr/bin/env ucode

'use strict';

import { pack, unpack}  from 'struct';
import * as uloop from 'uloop';
import * as ubus from 'ubus';
import { app, instance } from './common.uc';

// TODO settings, read 'em
const DSL_VID = 7;
const ATM_VPI = 8;
const ATM_VCI = 35;
const ATM_ENCAP = 0; // 0=LLC, 1=VCMUX
const ATM_LINK = 0; // 0=EoA, 6=PPPoA, 7=IPoA

const DATA_VID = 2000;

const STATE_NUM = [
	3, // LSTATE_MAP_SILENT
	7, // LSTATE_MAP_SHOWTIME_TC_SYNC
	3, // LSTATE_MAP_SILENT // TODO 2=0?
	4, // LSTATE_MAP_HANDSHAKE
	5, // LSTATE_MAP_FULL_INIT
];
const STATE_NAME = [
	"Silent",
	"Showtime with TC-Layer sync",
	"Silent",
	"Training", // Handshake
	"Full init",
];
const MODULATION = [
	[ "T1.413",    "ADSL1" ],
	[ "G.992.1",   "ADSL G.dmt" ],
	[ "G.992.2",   "ADSL G.lite" ],
	[ "G.992.3/4", "ADSL2 G.dmt.bis" ],
	[ "G.992.5",   "ADSL2+" ],
	[ "G.992.x",   "ATM auto-select" ], // config only
	[ "G.993.2",   "VDSL2" ],
	[ "G.99x",     "PTM/ATM auto-select" ], // config only
];
const MODULATION_AUTO = length(MODULATION) - 1;
const ANNEX = [ "A", "B", "I", "M", "A/L", "A/L/M", "J", "B/J", "auto", ];
const ANNEX_AUTO = length(ANNEX) - 1; // config only
const PROFILES = [ "35b", "30a", "17b", "12b", "12a", "8d", "8c", "8b", "8a" ];
const ALL_PROFILES_MASK = (1 << length(PROFILES)) - 1;

let client = {
	conn: null,
	line: [],
	metrics: {
		chipset: "EcoNet EN75xx",
	},

	startup: function() {
		// remove the local vlan
		this.netif_vlan_delete(this.interface_link, DATA_VID);

		this.conn = ubus.connect();
		if (!this.conn) {
			this.error = "couldn't connect to ubus";
			return false;
		}

		if (!this.conn.publish("dsl", {
			"metrics" :    { call: (req, msg) => req.reply(instance.get_metrics()), },
			"statistics" : { call: (req, msg) => req.reply({}), },
			"retrain" :    { call: (req, msg) => req.reply(instance.retrain()), },
			"dump" :       { call: (req, msg) => req.reply({ line: instance.line }), },
		})) {
			this.error = ubus.error();
			return false;
		}

		uloop.timer(1, () => {
			// our custom server opcode to get server side metrics
			instance.send_command(32);

			// remove the remote vlan
			instance.send_link_del(true, DATA_VID);
			instance.send_link_del(false, DATA_VID);
		});

		uloop.interval(1000, () => instance.send_get_line_obj());

		printf("xdsl client started on interface %s, mac %s\n", this.interface, hexenc(this.interface_mac));
	},

	shutdown: function() {
		// remove local and the remote vlans
		this.netif_vlan_delete(this.interface_link, DATA_VID);
		this.send_link_del(true, DATA_VID);
		this.send_link_del(false, DATA_VID);

		this.conn?.disconnect();
	},

	// vendor opcodes
	// https://github.com/hitech95/openwrt_tplink_vx830v_rbctrl-dsl/blob/master/docs/xdsl/payloads.md
	get_remote_error: function(fn, payload) {
		if (length(payload) != 4)
			return null;
		let v = unpack(">I", payload);
		if (v[0] != 0)
			printf("%s: remote error: %s\n", fn, v[0]);
		return v[0];
	},
	check_remote_error: function(fn, payload) {
		let error = this.get_remote_error(fn, payload);
		if (error == null)
			return false;
	},
	create_remote_link: function() {
		let modulation = MODULATION[instance.line[2]], ptm = instance.line[2] == 6;
		printf("modulation is %s (%s), creating remote %s link\n",
			modulation[0], modulation[1], ptm ? "ptm" : "atm");
		if (ptm)
			instance.send_link_ptm_link_add(true, DSL_VID, DATA_VID);
		else
			instance.send_atm_link_add(true, ATM_VPI, ATM_VCI, ATM_ENCAP, ATM_LINK, DSL_VID, DATA_VID);
	},
	create_vlan: function(ptm) {
		printf("remote %s link established, creating local vlan\n", ptm ? "ptm" : "atm");
		if (!this.netif_vlan_get_or_create(this.interface_link, DATA_VID, true)) {
			this.error = `error creating vlan: ${this.error}`;
			uloop.end();
		}
	},
	response_1: function(payload) { // dsl_config_up
		return this.check_remote_error("dsl_config_up", payload);
	},
	response_2: function(payload) { // dsl_get_line_obj
		if (length(payload) != 63)
			return false;

		let v = unpack(">IBBBBIIIIIIIIIIIIBHI", payload);
		if (v[0] != 0) {
			printf("ignoring dsl_get_line_obj response: remote error %d\n", v[0]);
			return;
		}

		let old_state = this.line[1];
		this.line = v;

		if (old_state == v[1])
			return;

		printf("link state change: %s -> %s\n", STATE_NAME[old_state], STATE_NAME[v[1]]);

		// remove local vlan if line in not up
		if (v[1] != 1) {
			this.netif_vlan_delete(this.interface_link, DATA_VID);
			return;
		}

		uloop.timer(50, () => instance.create_remote_link());
	},
	response_3: function(payload) { // dsl_config_down
		return this.check_remote_error("dsl_config_down", payload);
	},
	response_4: function(payload) { // dsl_get_channel_stats
		printf("dsl_get_channel_stats %s\n", hexenc(payload)); // TODO
	},
	response_5: function(payload) { // atm_link_add
		let ret = this.get_remote_error("atm_link_add", payload);
		if (ret == null)
			return false;
		if (ret == 0)
			uloop.timer(50, () => instance.create_vlan(false));
	},
	response_6: function(payload) { // atm_link_del
		return this.check_remote_error("atm_link_del", payload);
	},
	response_15: function(payload) { // ptm_link_add
		let ret = this.get_remote_error("ptm_link_add", payload);
		if (ret == null)
			return false;
		if (ret == 0)
			uloop.timer(50, () => instance.create_vlan(true));
		/* TODO retries?
		else
			uloop.timer(50, () => instance.create_remote_link());
		*/
	},
	response_16: function(payload) { // ptm_link_del
		return this.check_remote_error("ptm_link_del", payload);
	},

	// custom opcodes
	response_32: function(payload) {
		if (!payload)
			return false;
		let metrics;
		try {
			metrics = json(payload);
		} catch (e) {
			return false;
		}
		printf("server metrics = %.J\n", metrics);
		this.metrics = { ...this.metrics, ...metrics, };
	},

	send_config_up: function(modulation, annex, bitswap, sra, profile) {
		let payload = pack(">BBBBII", modulation, annex, bitswap, sra, profile, 0);
		return this.send_command(1, payload);
	},
	send_get_line_obj: function() {
		return this.send_command(2);
	},
	send_config_down: function() {
		return this.send_command(3);
	},
	send_send_get_channel_stats: function() { // TODO 4
	},
	send_atm_link_add: function(enable, vpi, vci, encap, type, vid, vlan) {
		let payload = pack(">BBHIIIBBHBHB", 1, vpi, vci, 0, 0, 0, encap, type, vlan, true, vid, 0);
		return this.send_command(5, payload);
	},
	send_link_del: function(ptm, vlan) {
		let payload = pack(">HB", vlan, 3);
		return this.send_command(ptm ? 16 : 6, payload);
	},
	send_link_ptm_link_add: function(enable, vid, vlan) {
		let payload = pack(">BHHBH", enable, vid, 0, 0, vlan);
		return this.send_command(15, payload);
	},

	retrain: function() {
		this.send_config_down();
		// autodetect modulation and annex, allow all profiles
		this.send_config_up(MODULATION_AUTO, ANNEX_AUTO, false, true, ALL_PROFILES_MASK);
		this.send_config_up(MODULATION_AUTO, ANNEX_AUTO, true, true, ALL_PROFILES_MASK);
	},

	get_metrics: function() {
		let metrics = {
			...this.metrics,
			up: this.line[1] == 1,
			state_num: STATE_NUM[this.line[1]],
			state: STATE_NAME[this.line[1]],
		};

		if (!metrics.up)
			return metrics;

		let standard = MODULATION[this.line[2]], profile;
		for (let i = 0x100, j = 0; i > 0; i >>= 1, j++)
			if (this.line[18] & i) {
				profile = PROFILES[j];
				break;
			}
		let mode = standard[1];
		if (profile)
			mode += ", Profile " + profile;
		mode = standard[0] + " (" + mode + ")";

		return {
			...metrics,
			standard: standard[0],
			profile: profile,
			mode: mode,
			annex: ANNEX[this.line[4]],
			uptime: this.line[19],
			downstream: {
				data_rate: this.line[5] * 1000,
				attndr: this.line[7] * 1000,
				snr: this.line[9] / 10.0,
				satn: this.line[11] / 10.0, // TODO or latn?
				actatp: this.line[13] / 10.0,
			},
			upstream: {
				data_rate: this.line[6] * 1000,
				attndr: this.line[8] * 1000,
				snr: this.line[10] / 10.0,
				satn: this.line[12] / 10.0, // TODO or latn?
				actatp: this.line[14] / 10.0,
			},
		};
	},
};
proto(client, app);

if (!client.run("lan0")) {
	print(instance.error, "\n");
	return 1;
}

return 0;
