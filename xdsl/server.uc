#!/usr/bin/env ucode

'use strict';

import { pack, unpack}  from 'struct';
import { app, instance } from './common.uc';

let server = {
	metrics: {},

	startup: function() {
		let map = {};
		let line = this.read_oneline("/proc/tc3162/adsl_fwver");
		for (let pair in split(line, " ")) {
			let kv = split(pair, ":");
			if (length(kv) == 2)
				map[kv[0]] = kv[1];
		}

		if ("HwVer" in map)
			this.metrics["hardware_version"] = map["HwVer"];
		if ("FwVer" in map)
			this.metrics["firmware_version"] = map["FwVer"];

		printf("xdsl server started on interface %s, mac %s\n", this.interface, hexenc(this.interface_mac));
		printf("server metrics = %.J\n", this.metrics);
	},

	// vendor opcodes
	// https://github.com/hitech95/openwrt_tplink_vx830v_rbctrl-dsl/blob/master/docs/xdsl/responses.md
	command_1: function(payload) { // dsl_config_up
		if (length(payload) != 12)
			return false;
		let v = unpack(">BBBBII", payload);
		printf("dsl_config_up: modulation=%u annex=%u bitswap=%s sra=%s profile=0x%x\n",
			v[0], v[1], v[2] != 0, v[3] != 0, v[4]);
	},
	command_2: function(payload) { // dsl_get_line_obj
		if (payload)
			return false;
		//printf("dsl_get_line_obj\n");
	},
	command_3: function(payload) { // dsl_config_down
		if (payload)
			return false;
		printf("dsl_config_down\n");
	},
	command_4: function(payload) { // dsl_get_channel_stats
		if (payload)
			return false;
		printf("dsl_get_channel_stats\n");
	},
	command_5: function(payload) { // atm_link_add
		if (length(payload) != 18)
			return false;
		let v = unpack(">BBHIIIBBHBHB", payload);
		printf("atm_link_add: qos=%u vpi=%u vci=%u pcr=%u scr=%u mbs=%u encap=%u type=%u vlan=%u tag=%s vid=%u prio=%u\n",
			v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9] != 0, v[10], v[11]);
	},
	command_6: function(payload) { // atm_link_del
		if (length(payload) != 3)
			return false;
		let v = unpack(">HB", payload);
		printf("atm_link_del: vlan=%u delete=%s\n", v[0], v[1] == 3);
	},
	command_15: function(payload) { // ptm_link_add
		if (length(payload) != 8)
			return false;
		let v = unpack(">BHHBH", payload);
		printf("ptm_link_add: enable=%s vid=%u priority=%u vlan=%u\n", v[0] != 0, v[1], v[2], v[4]);
	},
	command_16: function(payload) { // ptm_link_del
		if (length(payload) != 3)
			return false;
		let v = unpack(">HB", payload);
		printf("ptm_link_del: vlan=%u delete=%s\n", v[0], v[1] == 3);
	},
	command_20: function(payload) { // this *SETS* the eth0.1.500 mac
		if (length(payload) != 6)
			return false;
		let v = unpack(">6*", payload);
		printf("set_mac: mac=%s\n", hexenc(v[0]));
	},

	// custom opcodes
	command_32: function(payload) {
		if (payload)
			return false;
		printf("metrics\n");
		return sprintf("%J", this.metrics);
	},
};
proto(server, app);

if (!server.run("eth0.1")) {
	print(instance.error, "\n");
	return 1;
}

return 0;
