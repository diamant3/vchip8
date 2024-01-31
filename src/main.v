module main

import rand
import os
import flag

import gg
import gx

struct Gui {
mut:
	gg &gg.Context = unsafe { nil }
	pixels []int
}

@[heap]
struct Vchip8 {
mut:
	reg []u8
	mem []u8
	gfx []u8
	key []u8
	dt u8
	st u8
	draw_flag bool
	audio_flag bool
	ip u16
	pc u16
	opcode u16
	stack []u16
	sp u16
}

const reg_len = 16
const mem_len = 4096
const gfx_len = 64 * 32
const key_len = 16
const stack_len = 16
const font_set = [
    0xf0, 0x90, 0x90, 0x90, 0xf0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xf0, 0x10, 0xf0, 0x80, 0xf0, // 2
    0xf0, 0x10, 0xf0, 0x10, 0xf0, // 3
    0x90, 0x90, 0xf0, 0x10, 0x10, // 4
    0xf0, 0x80, 0xf0, 0x10, 0xf0, // 5
    0xf0, 0x80, 0xf0, 0x90, 0xf0, // 6
    0xf0, 0x10, 0x20, 0x40, 0x40, // 7
    0xf0, 0x90, 0xf0, 0x90, 0xf0, // 8
    0xf0, 0x90, 0xf0, 0x10, 0xf0, // 9
    0xf0, 0x90, 0xf0, 0x90, 0x90, // A
    0xe0, 0x90, 0xe0, 0x90, 0xe0, // B
    0xf0, 0x80, 0x80, 0x80, 0xf0, // C
    0xe0, 0x90, 0x90, 0x90, 0xe0, // D
    0xf0, 0x80, 0xf0, 0x80, 0xf0, // E
    0xf0, 0x80, 0xf0, 0x80, 0x80  // F
]

fn (mut vchip8 Vchip8) vchip8_start() {
	for loc, font in font_set {
		vchip8.mem[0x50 + loc] = u8(font)
	}

	vchip8.pc = 0x200
}

fn (mut vchip8 Vchip8) vchip8_load(rom_path string) {
	if os.file_ext(rom_path) == '.ch8' {
		data := os.read_bytes(rom_path) or { panic(err) }
		for loc, datum in data {
			vchip8.mem[0x200 + loc] = datum
		}
	} else {
		println("Incompatible CHIP-8 ROM.")
	}
}

fn (mut vchip8 Vchip8) vchip8_cycle() {
	vchip8.opcode = vchip8.mem[vchip8.pc] << 4 | vchip8.mem[vchip8.pc + 1]
	println("RUNNING: ${vchip8.opcode}")

	match vchip8.opcode & 0xF000 {
		0x0000 {
			match vchip8.opcode & 0x00ff {
				0xe0 {
					unsafe {
						vchip8.gfx.reset()
					}
				}
				0xee {
					vchip8.sp -= 1
					vchip8.pc = vchip8.stack[vchip8.sp]
				}
				else { println("[!] Unimplemented opcode ${vchip8.opcode}") }
			}
		}
		0x1000 { vchip8.pc = vchip8.opcode & 0x0fff }
		0x2000 {
			vchip8.stack[vchip8.sp] = vchip8.pc
			vchip8.sp += 1
			vchip8.pc = vchip8.opcode & 0x0fff
		}
		0x3000 {
			regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
			byte_addr := u8(vchip8.opcode & 0x00ff)

			if regx == byte_addr { vchip8.pc += 4 }
			else { vchip8.pc += 2 }
		}
		0x4000 {
			regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
			byte_addr := u8(vchip8.opcode & 0x00ff)

			if regx != byte_addr { vchip8.pc += 4 }
			else { vchip8.pc += 2 }
		}
		0x5000 {
			regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
			regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

			if regx == regy { vchip8.pc += 4 }
			else { vchip8.pc += 2 }
		}
		0x6000 {
			regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
			byte_addr := u8(vchip8.opcode & 0x00ff)

			vchip8.reg[regx] = byte_addr
			vchip8.pc += 2
		}
		0x7000 {
			byte_addr := u8(vchip8.opcode & 0x00ff)

			vchip8.reg[(vchip8.opcode & 0x0f00) >> 8] += byte_addr
			vchip8.pc += 2
		}
		0x8000 {
			match vchip8.opcode & 0x000f {
				0x0 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					vchip8.reg[regx] = vchip8.reg[regy]
					vchip8.pc += 2
				}
				0x1 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					vchip8.reg[regx] |= vchip8.reg[regy]
					vchip8.pc += 2
				}
				0x2 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					vchip8.reg[regx] &= vchip8.reg[regy]
					vchip8.pc += 2
				}
				0x3 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					vchip8.reg[regx] ^= vchip8.reg[regy]
					vchip8.pc += 2
				}
				0x4 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					result := vchip8.reg[regx] + vchip8.reg[regy]
					vchip8.reg[regx] += vchip8.reg[regy]
					if result > 0xff { vchip8.reg[0xf] = 1 }
					else { vchip8.reg[0xf] = 0 }

					vchip8.pc += 2
				}
				0x5 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					mut vf := u8(0)
					if vchip8.reg[regx] >= vchip8.reg[regy] { vf = 1 }

					vchip8.reg[regx] -= vchip8.reg[regy]
					vchip8.reg[0xf] = vf
					vchip8.pc += 2
				}
				0x6 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					mut vf := vchip8.reg[regx] & 0x1

					vchip8.reg[regx] >>= 0x1
					vchip8.reg[0xf] = vf
				}
				0x7 {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

					mut vf := u8(0)
					if vchip8.reg[regy] >= vchip8.reg[regx] { vf = 1 }

					vchip8.reg[regx] = vchip8.reg[regy] - vchip8.reg[regx] 

					vchip8.reg[0xf] = vf
					vchip8.pc += 2
				}
				0xe {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
					regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]
					mut vf := vchip8.reg[regx] & 0x80
					vchip8.reg[regx] = vchip8.reg[regy] << 0x7
					vchip8.reg[0xf] = vf
				}
				else { println("[!] Unimplemented opcode: ${vchip8.opcode}") }
			}
		}
		0x9000 {
			regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
			regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]

			if vchip8.reg[regx] != vchip8.reg[regy] { vchip8.pc += 4 }
			else { vchip8.pc += 2 }
		}
		0xa000 {
			addr := vchip8.opcode & 0x0fff

			vchip8.ip = addr
			vchip8.pc += 2
		}
		0xb000 {
			addr := vchip8.opcode & 0x0fff
			vchip8.pc = addr + vchip8.reg[0x0]
		}
		0xc000 {
			regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
			byte_addr := u8(vchip8.opcode & 0x00ff)
			random_number := rand.int_in_range(0, 256) or { panic(err) }
			vchip8.reg[regx] = u8(random_number & byte_addr)
		}
		0xd000 {
			width := 8
			height := vchip8.opcode & 0x000f

			for row in 0..height {
				regy := vchip8.reg[(vchip8.opcode & 0x0f00) >> 4]
	
				h := row + vchip8.reg[regy]
				if h >= 32 { break }

				mut sprite := vchip8.mem[vchip8.ip + row]
				for col in 0..width {
					regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]

					w := col + vchip8.reg[regx]
					if w >= 64 { break }

					if (sprite & 0x80) > 0 {
						x := vchip8.reg[regx] + col
						y := vchip8.reg[regy] + row

						pixel_data := x + (y * 64)
						vchip8.gfx[pixel_data] ^= 0x1
						if vchip8.gfx[pixel_data] == 1 {
							vchip8.reg[0xf] = 1
						}
					}

					sprite <<= 1
				}
			}

			vchip8.pc += 2
		}
		0xe000 {
			match vchip8.opcode & 0x00ff {
				0x9e { println("NOP") }
				0xa1 { println("NOP") }
				else { println("[!] Unimplemented opcode ${vchip8.opcode}") }
			}
		}
		0xf0000 {
			match vchip8.opcode & 0x00ff {
				0x07 { println("NOP") }
				0x0a { println("NOP") }
				0x15 { println("NOP") }
				0x18 { println("NOP") }
				0x1e { println("NOP") }
				0x29 { println("NOP") }
				0x33 { println("NOP") }
				0x55 { println("NOP") }
				0x65 { println("NOP") }
				else { println("[!] Unimplemented opcode ${vchip8.opcode}") }
			}
		}
		else { println("[!] Unimplemented opcode ${vchip8.opcode}") }
	}
}

fn main() {
	mut machine := &Vchip8 {
		reg: []u8 { len: reg_len, init: 0 },
		mem: []u8 { len: mem_len, init: 0 },
		gfx: []u8 { len: gfx_len, init: 0 },
		key: []u8 { len: key_len, init: 0 },
		dt: 0,
		st: 0,
		draw_flag: false,
		audio_flag: false,
		ip: 0,
		pc: 0,
		opcode: 0,
		stack: []u16 { len: stack_len, init: 0 }
		sp: 0
	}

	mut parser := flag.new_flag_parser(os.args)
	parser.application('vchip8')
	parser.version('1.0.0')
	parser.description('CHIP-8 emulator written in V')
	parser.skip_executable()
	rom_path := parser.string(
		'rom',
		`r`, 
		'', 
		'load the rom'
	)
	parser.finalize() or { 
		println(parser.usage())
		return
	}

	ext := os.file_ext(rom_path)
	if ext.compare('.ch8') == 0 {
		machine.vchip8_start()
		machine.vchip8_load(rom_path)

		win_width := 640
		win_height := 320

		mut gui := &Gui {
			gg: unsafe { 0 }
			pixels: []int{ len: gfx_len, init: 0 }
		}

		gui.gg = gg.new_context(
			bg_color: gx.black
			width: win_width
			height: win_height
			frame_fn: machine.frame
			user_data: gui
		)
		gui.gg.run()
	} else {
		println(parser.usage()) 
		println("[!] Unknown file or path.")
	}
}

fn (mut vchip8 Vchip8) frame(mut gui Gui) {
	gui.gg.begin()
	vchip8.vchip8_cycle()
	gui.gg.end()
}
