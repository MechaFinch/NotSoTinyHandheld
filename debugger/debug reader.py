#STARTFILE debug.py

# reads from debugger
from spi_device import SPIDevice

from machine import Pin
from rp2 import PIO

import time

def run():
    clk_pin = Pin("GP21", mode=Pin.IN)
    cido_pin = Pin("GP20", mode=Pin.IN)
    codi_pin = Pin("GP19", mode=Pin.IN)
    cs_pin = Pin("GP18", mode=Pin.IN)
    cd_pin = Pin("GP17", mode=Pin.IN)

    """
    clk_data = [0] * 1000
    codi_data = [0] * 1000
    
    for i in range(1000):
        clk_data[i] = clk_pin.value()
        codi_data[i] = codi_pin.value()
        time.sleep_us(50)
    
    for i in range(1000):
        print(f"clk {clk_data[i]}   codi {codi_data[i]}")
    
    return
    """

    device = SPIDevice("GP21", "GP20", "GP19", "GP18", "GP17")
    
    while True:
        device.read_enabled = True
        
        # TODO
        # FIGURE OUT CD PROCESSING
        
        # discard data until CD low
        while True:
            if len(device.rx_queue) > 0:
                if device.cd_queue[0] != 0:
                    break
                else:
                    device.rx_queue.pop(0)
                    device.cd_queue.pop(0)
        
        # wait for data
        while True:
            if len(device.rx_queue) >= 53:
                break
        
        device.read_enabled = False
        
        # output data
        reg_ip = pull_dword(device)
        reg_bp = pull_dword(device)
        reg_sp = pull_dword(device)
        
        reg_a = pull_word(device)
        reg_b = pull_word(device)
        reg_c = pull_word(device)
        reg_d = pull_word(device)
        reg_i = pull_word(device)
        reg_j = pull_word(device)
        reg_k = pull_word(device)
        reg_l = pull_word(device)
        
        reg_f = pull_word(device)
        reg_pf = pull_word(device)
        
        inst_oop = pull_byte(device)
        inst_cop = pull_byte(device)
        inst_rim = pull_byte(device)
        inst_bio = pull_byte(device)
        inst_imm = pull_dword(device)
        inst_ei8 = pull_byte(device)
        
        icount = pull_dword(device)
        ecount = pull_dword(device)
        mcount = pull_dword(device)
        
        print(f"IP       BP       SP")
        print(f"{reg_ip:08X} {reg_bp:08X} {reg_sp:08X}")
        print()
        print(f"A    B    C    D")
        print(f"{reg_a:04X} {reg_b:04X} {reg_c:04X} {reg_d:04X}")
        print(f"I    J    K    L")
        print(f"{reg_i:04X} {reg_j:04X} {reg_k:04X} {reg_l:04X}")
        print()
        print(f"F    PF")
        print(f"{reg_f:04X} {reg_pf:04X}")
        print()
        print(f"OOP: {inst_oop:02X}")
        print(f"COP: {inst_cop:02X}")
        print(f"RIM: {inst_rim:02X}")
        print(f"BIO: {inst_bio:02X}")
        print(f"IMM: {inst_imm:08X}")
        print(f"EI8: {inst_ei8:02X}")
        print()
        print(f"Instruction Count: {icount}")
        print(f"Exec Clock Count:  {ecount}")
        print(f"Mem Clock Count:   {mcount}")
        print()
        print()
        
        # clear any other data
        device.rx_queue.clear()
        
        time.sleep_us(250_000)
        
def pull_byte(d):
    return d.rx_queue.pop(0)

def pull_word(d):
    lower = d.rx_queue.pop(0)
    upper = d.rx_queue.pop(0)
    return (upper << 8) | lower

def pull_dword(d):
    b0 = d.rx_queue.pop(0)
    b1 = d.rx_queue.pop(0)
    b2 = d.rx_queue.pop(0)
    b3 = d.rx_queue.pop(0)
    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0


#ENDFILE
