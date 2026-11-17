'use strict';

import { readfile } from 'fs';
import * as rtnl from "rtnl";
import * as socket from 'socket';
import { pack, unpack}  from 'struct';
import * as uloop from 'uloop';

const PROTOCOL = 0x88b5;
const MAX_PACKET_LEN = 1514;
const MGMT_VID = 500;
const MAC_NULL = chr(0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
const MAC_BROADCAST = chr(0xff, 0xff, 0xff, 0xff, 0xff, 0xff);
const CRC16ARC_TABLE = [
	0x0000, 0xC0C1, 0xC181, 0x0140, 0xC301, 0x03C0, 0x0280, 0xC241,
	0xC601, 0x06C0, 0x0780, 0xC741, 0x0500, 0xC5C1, 0xC481, 0x0440,
	0xCC01, 0x0CC0, 0x0D80, 0xCD41, 0x0F00, 0xCFC1, 0xCE81, 0x0E40,
	0x0A00, 0xCAC1, 0xCB81, 0x0B40, 0xC901, 0x09C0, 0x0880, 0xC841,
	0xD801, 0x18C0, 0x1980, 0xD941, 0x1B00, 0xDBC1, 0xDA81, 0x1A40,
	0x1E00, 0xDEC1, 0xDF81, 0x1F40, 0xDD01, 0x1DC0, 0x1C80, 0xDC41,
	0x1400, 0xD4C1, 0xD581, 0x1540, 0xD701, 0x17C0, 0x1680, 0xD641,
	0xD201, 0x12C0, 0x1380, 0xD341, 0x1100, 0xD1C1, 0xD081, 0x1040,
	0xF001, 0x30C0, 0x3180, 0xF141, 0x3300, 0xF3C1, 0xF281, 0x3240,
	0x3600, 0xF6C1, 0xF781, 0x3740, 0xF501, 0x35C0, 0x3480, 0xF441,
	0x3C00, 0xFCC1, 0xFD81, 0x3D40, 0xFF01, 0x3FC0, 0x3E80, 0xFE41,
	0xFA01, 0x3AC0, 0x3B80, 0xFB41, 0x3900, 0xF9C1, 0xF881, 0x3840,
	0x2800, 0xE8C1, 0xE981, 0x2940, 0xEB01, 0x2BC0, 0x2A80, 0xEA41,
	0xEE01, 0x2EC0, 0x2F80, 0xEF41, 0x2D00, 0xEDC1, 0xEC81, 0x2C40,
	0xE401, 0x24C0, 0x2580, 0xE541, 0x2700, 0xE7C1, 0xE681, 0x2640,
	0x2200, 0xE2C1, 0xE381, 0x2340, 0xE101, 0x21C0, 0x2080, 0xE041,
	0xA001, 0x60C0, 0x6180, 0xA141, 0x6300, 0xA3C1, 0xA281, 0x6240,
	0x6600, 0xA6C1, 0xA781, 0x6740, 0xA501, 0x65C0, 0x6480, 0xA441,
	0x6C00, 0xACC1, 0xAD81, 0x6D40, 0xAF01, 0x6FC0, 0x6E80, 0xAE41,
	0xAA01, 0x6AC0, 0x6B80, 0xAB41, 0x6900, 0xA9C1, 0xA881, 0x6840,
	0x7800, 0xB8C1, 0xB981, 0x7940, 0xBB01, 0x7BC0, 0x7A80, 0xBA41,
	0xBE01, 0x7EC0, 0x7F80, 0xBF41, 0x7D00, 0xBDC1, 0xBC81, 0x7C40,
	0xB401, 0x74C0, 0x7580, 0xB541, 0x7700, 0xB7C1, 0xB681, 0x7640,
	0x7200, 0xB2C1, 0xB381, 0x7340, 0xB101, 0x71C0, 0x7080, 0xB041,
	0x5000, 0x90C1, 0x9181, 0x5140, 0x9301, 0x53C0, 0x5280, 0x9241,
	0x9601, 0x56C0, 0x5780, 0x9741, 0x5500, 0x95C1, 0x9481, 0x5440,
	0x9C01, 0x5CC0, 0x5D80, 0x9D41, 0x5F00, 0x9FC1, 0x9E81, 0x5E40,
	0x5A00, 0x9AC1, 0x9B81, 0x5B40, 0x9901, 0x59C0, 0x5880, 0x9841,
	0x8801, 0x48C0, 0x4980, 0x8941, 0x4B00, 0x8BC1, 0x8A81, 0x4A40,
	0x4E00, 0x8EC1, 0x8F81, 0x4F40, 0x8D01, 0x4DC0, 0x4C80, 0x8C41,
	0x4400, 0x84C1, 0x8581, 0x4540, 0x8701, 0x47C0, 0x4680, 0x8641,
	0x8201, 0x42C0, 0x4380, 0x8341, 0x4100, 0x81C1, 0x8081, 0x4040,
];

let base = {
	error: null,

	read_oneline: function(filename) {
		let lines = split(readfile(filename, 512), "\n");
		if (length(lines) < 1)
			return null;
		return trim(lines[0]);
	},

	netif_get_mac: function(dev) {
		let ret = rtnl.request(rtnl.const.RTM_GETLINK, 0, { dev });
		if (!ret) {
			this.error = `RTM_GETLINK failed: ${rtnl.error()}`;
			return null;
		}
		return ret["address"];
	},

	netif_exists: function(dev) {
		return this.netif_get_mac(dev) != null;
	},

	netif_updown: function(dev, up) {
		let ret = rtnl.request(rtnl.const.RTM_SETLINK, 0, { dev, change: 1, flags: up ? 1 : 0 });
		if (!ret) {
			this.error = `RTM_SETLINK failed: ${rtnl.error()}`;
			return false;
		}
		return true;
	},

	netif_delete: function(dev) {
		let ret = rtnl.request(rtnl.const.RTM_DELLINK, 0, { dev });
		if (!ret) {
			this.error = `RTM_DELLINK failed: ${rtnl.error()}`;
			return false;
		}
		return true;
	},

	netif_vlan_get: function(dev, vid) {
		let ret = rtnl.request(rtnl.const.RTM_GETLINK, rtnl.const.NLM_F_DUMP, { dev });
		if (!ret) {
			this.error = `RTM_GETLINK failed: ${rtnl.error()}`;
			return null;
		}
		for (let i in ret)
			if ((i["link"] == dev) && (i["linkinfo"]["type"] == "vlan") && (i["linkinfo"]["id"] == vid))
				return i["dev"];
		return "";
	},

	netif_vlan_delete: function(dev, vid) {
		let netif = this.netif_vlan_get(dev, vid);
		if (netif) {
			printf("deleting vlan %u on interface %s\n", vid, dev);
			this.netif_delete(netif);
		}
	},

	netif_vlan_create: function(dev, vid, up) {
		let name = sprintf("%s.%u", dev, vid);
		let ret = rtnl.request(rtnl.const.RTM_NEWLINK, rtnl.const.NLM_F_CREATE | rtnl.const.NLM_F_EXCL, {
			ifname: name,
			link: dev,
			linkinfo: {
				type: "vlan",
				id: vid,
			},
			flags: up ? 1 : 0,
		});
		if (!ret) {
			this.error = `RTM_NEWLINK failed: ${rtnl.error()}`;
			return null;
		}

		return name;
	},

	netif_vlan_get_or_create: function(dev, vid, up) {
		let netifd = this.netif_vlan_get(dev, vid);
		if (netifd == null)
			return null;

		if (!this.netif_updown(dev, true))
			return null;

		if (netifd == "") {
			printf("creating vlan %u on interface %s\n", vid, dev);
			netifd = this.netif_vlan_create(dev, vid, up);
		} else {
			if (!this.netif_updown(netifd, up))
				return null;
		}

		return netifd;
	}
};

let raw_socket = {
	sock: null,
	protocol: null,
	interface: null,
	interface_mac: null,

	open: function(protocol, interface) {
		this.sock = socket.create(socket.AF_PACKET, socket.SOCK_RAW, protocol);
		if (!this.sock) {
			this.error = "error creating the socket";
			return false;
		}

		if (!this.sock.setopt(socket.SOL_SOCKET, socket.SO_BROADCAST, true)) {
			this.error = `setopt SO_BROADCAST failed: ${socket.error()}\n`;
			this.sock = null;
			return false;
		}

		if (!this.sock.bind({
			family: socket.AF_PACKET,
			protocol,
			interface,
			address: MAC_NULL,
		})) {
			this.error = `bind failed: ${socket.error()}\n`;
			this.sock = null;
			return false;
		}

		let mac = this.netif_get_mac(interface);
		if (!mac)
			return false;

		this.protocol = protocol;
		this.interface = interface;
		this.interface_mac = hexdec(replace(mac, ":", ""));
		return true;
	},

	close: function() {
		this.socket = null;
	},

	send_raw: function(data, address) {
		if (length(data) > MAX_PACKET_LEN) {
			this.error = `packet too large: ${length(data)}`;
			return false;
		}

		if (!this.sock.send(data, 0, {
			family: socket.AF_PACKET,
			protocol: this.protocol,
			interface: this.interface,
			hardware_type: socket.ARPHRD_ETHER,
			address: address ? address : MAC_NULL,
		})) {
			this.error = `send failed: ${socket.error()}\n`;
			return false;
		}
		return true;
	},

	receive_raw: function() {
		let data = this.sock.recv(MAX_PACKET_LEN, 0, {});
		if (!data) {
			this.error = `recv failed: ${socket.error()}\n`;
			return data;
		}
		return data;
	},
};
proto(raw_socket, base);

// https://github.com/hitech95/openwrt_tplink_vx830v_rbctrl-dsl/blob/master/docs/protocol.md
let frame_socket = {
	seq: 0,

	// https://crc-calc.com/
	// Model: Custom (Modified) (16-bit)
	// Poly: 0x8005, Init: 0x0000, XorOut: 0x0000
	crc16arc: function(data, start) {
		let crc = start ? start : 0;
		for (let i = 0; i < length(data); i++) {
			let idx = (crc ^ ord(data, i)) & 0xFF;
			crc = (crc >> 8) ^ CRC16ARC_TABLE[idx];
		}
		return crc;
	},

	send_frame: function(magic, opcode, payload, dst) {
		let data = pack(">6*6*HBBIH",
				dst ? dst : MAC_BROADCAST,
				this.interface_mac,
				this.protocol,
				magic,
				opcode,
				this.seq++,
				length(payload));

		let crc = this.crc16arc(substr(data, 0x0e, 8));
		crc = this.crc16arc("\0\0", crc);
		if (length(payload) > 0)
			crc = this.crc16arc(payload, crc);

		data += pack(">H", crc);
		if (length(payload) > 0)
			data += payload;

		return this.send_raw(data);
	},

	send_command: function(opcode, payload) {
		return this.send_frame(0x11, opcode, payload);
	},

	send_response: function(opcode, payload, dst) {
		return this.send_frame(0x10, opcode, payload, dst);
	},

	receive_frame: function() {
		let data = this.receive_raw();
		if (!data)
			return data;

		if (length(data) < 0x19) {
			this.error = `packet too small: ${length(data)}`;
			return null;
		}

		let v = unpack(">6*6*HBBIHHB", data);
		if (v[6] > 0 && length(data) < 0x19 + v[6] - 1) {
			this.error = `packet too small: ${length(data)}, payload size: ${v[6]}`;
			return null;
		}

		let crc = this.crc16arc(substr(data, 0x0e, 8));
		crc = this.crc16arc("\0\0", crc);
		crc = this.crc16arc(substr(data, 0x18, v[6]), crc);

		if (crc != v[7]) {
			this.error = `packet crc mismatch: ${crc}, expected ${v[7]}`;
			return null;
		}

		if (!(v[3] in [0x10, 0x11])) {
			this.error = `unknown packet magic: ${v[3]}`;
			return null;
		}

		let payload = v[6] > 0 ? substr(data, 0x18, v[6]) : null;

		return {
			src: v[1],
			response: v[3] == 0x10,
			opcode: v[4],
			payload,
		};
	},
};
proto(frame_socket, raw_socket);

// 'this' for callbacks
export let instance;

export let app = {
	interface_link: null,
	startup: null,
	shutdown: null,

	unhandled: function(response, opcode, payload) {
		printf("unhandled %s %d with %d bytes payload: %s\n",
			response ? "response" : "command", opcode, length(payload), hexenc(payload));
	},

	run: function(interface) {
		instance = this;

		if (!this.netif_exists(interface)) {
			this.error = `network interface ${interface} does not exist`;
			return false;
		}

		let interface_mgmt = this.netif_vlan_get_or_create(interface, MGMT_VID, true);
		if (!interface_mgmt)
			return false;

		if (!uloop.init()) {
			this.error = `uloop init failed: ${uloop.error()}`;
			return false;
		}

		if (!this.open(PROTOCOL, interface_mgmt))
			return false;

		this.interface_link = interface;

		uloop.handle(this.sock, () => {
			let frame = instance.receive_frame();
			if (!frame) {
				uloop.end();
				return;
			}

			let handler_name = (frame.response ? "response_" : "command_") + frame.opcode;
			let handler = instance[handler_name];
			if (!handler) {
				instance.unhandled(frame.response, frame.opcode, frame.payload);
				return;
			}

			let payload = call(handler, instance, null, frame.payload);
			if (payload == false) {
				printf("handler %s refused payload %s (%d bytes)\n",
					handler_name, hexenc(frame.payload), length(frame.payload));
				return;
			}

			if (!payload)
				return;

			if (!instance.send_response(frame.opcode, payload, frame.src))
				uloop.end();
		}, uloop.ULOOP_READ);

		uloop.signal('SIGINT', () => {
			print("received SIGINT, exiting\n");
			uloop.end();
		});
		uloop.signal('SIGTERM', () => {
			print("received SIGTERM, exiting\n");
			uloop.end();
		});

		let ret;
		if (this.startup)
			ret = this.startup();

		if (ret != false)
			ret = uloop.run();

		if (this.shutdown)
			this.shutdown();

		this.close();

		return ret;
	},
};
proto(app, frame_socket);
