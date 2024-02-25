module main

//import rand
import os
import flag
import gg
import gx

struct Vchip8 {
mut:
    reg [16]u8
    mem [4096]u8
    gfx [2048]u8
    key [16]u8
    dt u8
    st u8
    draw_flag bool
    audio_flag bool
    i u16
    pc u16
    opcode u16
    stack [16]u16
    sp u16
}

struct Vchip8State {
mut:
    gg &gg.Context = unsafe { nil }
    vchip8 &Vchip8 = unsafe { nil }
}

const font_set = [
    u8(0xf0), 0x90, 0x90, 0x90, 0xf0, // 0
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

fn vchip8_start() &Vchip8 {
        mut vchip8 := &Vchip8 {
        reg: [16]u8 {},
        mem: [4096]u8 {},
        gfx: [2048]u8 {},
        key: [16]u8 {},
        dt: 0,
        st: 0,
        draw_flag: false,
        audio_flag: false,
        i: 0,
        pc: 0,
        opcode: 0,
        stack: [16]u16 {},
        sp: 0
    };

    for loc, data in font_set {
        vchip8.mem[0x50 + loc] = data
    }

    vchip8.pc = 0x200
    return vchip8
}

fn (mut vchip8 Vchip8) vchip8_load(rom_path string) {
    if os.file_ext(rom_path) == '.ch8' {
        buf := os.read_file(rom_path) or { panic(err) }
        for loc, datum in buf {
            vchip8.mem[0x200 + loc] = datum
        }
    } else {
        println("Incompatible CHIP-8 ROM.")
    }
}

fn (mut vchip8 Vchip8) vchip8_cycle() {
    for vchip8.pc < vchip8.mem.len {
        vchip8.opcode = u16(vchip8.mem[vchip8.pc]) << 8 | vchip8.mem[vchip8.pc + 1]
        //println("[*] opcode: ${vchip8.opcode.hex()} PC: ${vchip8.pc.hex()}")
        // os.execute('cls')
        // for i in 0..15 {
        //     eprint(" v${i}: ${vchip8.reg[i]}")
        // }
        // eprintln("")


        match vchip8.opcode & 0xf000 {
            0x0000 {
                match vchip8.opcode & 0x00ff {
                    0xe0 {
                        for bit in 0..vchip8.gfx.len {
                            vchip8.gfx[bit] = 0
                        }
                        vchip8.pc += 2
                    }
                    0xee {
                        vchip8.pc = vchip8.stack[vchip8.sp]
                        vchip8.stack[vchip8.sp] = 0
                        vchip8.sp -= 1
                        vchip8.pc += 2
                    }
                    else { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
                }
            }
            0x1000 {
                vchip8.pc = vchip8.opcode & 0x0fff 
            }
            0x2000 {
                vchip8.sp += 1
                vchip8.stack[vchip8.sp] = vchip8.pc
            	vchip8.pc = vchip8.opcode & 0x0fff
            }
            0x3000 {
            	regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
            	byte_addr := vchip8.opcode & 0x00ff

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
            	regy := vchip8.reg[(vchip8.opcode & 0x00f0) >> 4]

            	if regx == regy { vchip8.pc += 4 }
            	else { vchip8.pc += 2 }
            }
            0x6000 {
                byte_addr := u8(vchip8.opcode & 0x00ff)

                vchip8.reg[(vchip8.opcode & 0x0f00) >> 8] = byte_addr
                vchip8.pc += 2
            }
            0x7000 {
                byte_addr := vchip8.opcode & 0x00ff

                vchip8.reg[(vchip8.opcode & 0x0f00) >> 8] += u8(byte_addr)
                vchip8.pc += 2
            }
            0x8000 {
            	match vchip8.opcode & 0x000f {
            		0x0 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

            			vchip8.reg[x] = vchip8.reg[y]
            			vchip8.pc += 2
            		}
            		0x1 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

            			vchip8.reg[x] |= vchip8.reg[y]
            			vchip8.pc += 2
            		}
            		0x2 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

            			vchip8.reg[x] &= vchip8.reg[y]
            			vchip8.pc += 2
            		}
            		0x3 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

            			vchip8.reg[x] ^= vchip8.reg[y]
            			vchip8.pc += 2
            		}
            		0x4 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

                        result := u16(vchip8.reg[x]) + vchip8.reg[y]
                        vchip8.reg[x] = u8(result)
            			vchip8.reg[0xf] = if result > 0xff { u8(1) } else { u8(0) }
            			vchip8.pc += 2
            		}
            		0x5 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

            			mut vf := u8(0)
            			if vchip8.reg[x] >= vchip8.reg[y] { vf = 1 }

            			vchip8.reg[x] -= vchip8.reg[y]
            			vchip8.reg[0xf] = vf
            			vchip8.pc += 2
            		}
            		0x6 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			mut vf := vchip8.reg[x] & 0x1

            			vchip8.reg[x] >>= 0x1
            			vchip8.reg[0xf] = vf
                        vchip8.pc += 2
            		}
            		0x7 {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4

            			mut vf := u8(0)
            			if vchip8.reg[y] >= vchip8.reg[x] { vf = 1 }

            			vchip8.reg[x] = vchip8.reg[y] - vchip8.reg[x]

            			vchip8.reg[0xf] = vf
            			vchip8.pc += 2
            		}
            		0xe {
            			x := (vchip8.opcode & 0x0f00) >> 8
            			y := (vchip8.opcode & 0x00f0) >> 4
            			mut vf := (vchip8.reg[x] & 0x80) >> 0x7
            			vchip8.reg[x] = vchip8.reg[y] << 1
            			vchip8.reg[0xf] = vf
                        vchip8.pc += 2
            		}
            		else { println("[!] Unimplemented opcode: ${vchip8.opcode.hex()}") }
            	}
            }
            0x9000 {
            	x := (vchip8.opcode & 0x0f00) >> 8
            	y := (vchip8.opcode & 0x00f0) >> 4

            	if vchip8.reg[x] != vchip8.reg[y] { vchip8.pc += 4 }
            	else { vchip8.pc += 2 }
            }
            0xa000 {
                addr := vchip8.opcode & 0x0fff

                vchip8.i = addr
                vchip8.pc += 2
            }
            // 0xb000 {
            // 	addr := vchip8.opcode & 0x0fff
            // 	vchip8.pc = addr + vchip8.reg[0x0]
            // }
            // 0xc000 {
            // 	regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
            // 	byte_addr := u8(vchip8.opcode & 0x00ff)
            // 	random_number := rand.int_in_range(0, 256) or { panic(err) }
            // 	vchip8.reg[regx] = u8(random_number & byte_addr)
            // }
            0xd000 {
                mut xx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
                mut yy := vchip8.reg[(vchip8.opcode & 0x00f0) >> 4]
                height := vchip8.opcode & 0x000f
                vchip8.reg[0xf] = 0

                for yline in 0..height {
                    if (yy + yline) > 32 { yy = yy % 32 }
                    pixel := vchip8.mem[vchip8.i + yline]
                    for xline in 0..8 {
                        if (xx + xline) > 64 { xx = xx % 64 }

                        if (pixel & (0x80 >> xline)) > 0 {
                            target := (xx + xline) + ((yy + yline) * 64)
                            if vchip8.gfx[target] > 0 {
                                vchip8.reg[0xf] = 1
                            }

                            vchip8.gfx[target] ^= 1
                        }
                    }
                }

                vchip8.pc += 2
            }
            // 0xe000 {
            // 	match vchip8.opcode & 0x00ff {
            // 		0x9e { println("NOP") }
            // 		0xa1 { println("NOP") }
            // 		else { println("[!] Unimplemented opcode ${vchip8.opcode}") }
            // 	}
            // }
            0xf000 {
            	match vchip8.opcode & 0x00ff {
            		0x07 { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
            		0x0a { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
            		0x15 { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
            		0x18 { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
            		0x1e {
                        vchip8.i += vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
                        vchip8.pc += 2
                    }
            		0x29 { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
            		0x33 {
                       regx := vchip8.reg[(vchip8.opcode & 0x0f00) >> 8]
                       vchip8.mem[vchip8.i] = regx / 100
                       vchip8.mem[vchip8.i + 1] = (regx / 10) % 10
                       vchip8.mem[vchip8.i + 2] = (regx % 10)

                       vchip8.pc += 2
                    }
            		0x55 {
                        vx := (vchip8.opcode & 0x0f00) >> 8
                        for datum in 0..vx + 1 {
                            vchip8.mem[vchip8.i + datum] = vchip8.reg[datum]
                        }

                        vchip8.pc += 2
                    }
            		0x65 {
                        vx := (vchip8.opcode & 0x0f00) >> 8
                        for datum in 0..vx + 1 {
                            vchip8.reg[datum] = vchip8.mem[vchip8.i + datum]
                        }

                        vchip8.pc += 2
                    }
            		else { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
            	}
            }
            else { println("[!] Unimplemented opcode ${vchip8.opcode.hex()}") }
        }
    }
}

fn main() {
    mut state := &Vchip8State{}

    mut parser := flag.new_flag_parser(os.args)
    parser.application('vchip8')
    parser.version('1.0.0')
    parser.description('CHIP-8 interpreter written in V')
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
        state.vchip8 = vchip8_start()
        state.vchip8.vchip8_load(rom_path)

        state.gg = gg.new_context(
            bg_color: gx.black
            width: 640
            height: 320
            window_title: 'vchip8'
            frame_fn: frame
            user_data: state
        )
        spawn state.vchip8.vchip8_cycle()
        state.gg.run()

    } else {
        println(parser.usage())
        println("[!] Unknown file or path.")
        return
    }
}

fn frame(mut state Vchip8State) {
    state.gg.begin()

    for x in 0..64 {
        for y in 0..32 {
            index := x + (y * 64)
            if state.vchip8.gfx[index] > 0 {
                state.gg.draw_rect_filled(x * 10, y * 10, 10, 10, gx.yellow)
            }
        }
    }

    state.gg.end()
}
