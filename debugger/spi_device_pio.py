#STARTFILE spi_device.py

# SPI device (PIO version)

from machine import Pin
import rp2

@rp2.asm_pio()
def spi_sm():
    label("start")
    wait(0, gpio, 18)       # wait for CS low
    mov(isr, null)          # clear isr
    label("byte_loop")
    wrap_target()
    set(x, 7)               # bit counter
    label("bit_loop")
    jmp(pin, "start")       # stop if CS high
    wait(1, gpio, 21)       # wait for CLK high
    in_(pins, 1)            # read bit
    wait(0, gpio, 21)       # wait for CLK low
    jmp(x_dec, "bit_loop")  # loop until we have a full byte
    push()                  # push byte
    irq(0)                  # notify cpu
    wrap()
    

class SPIDevice:
    rx_queue = []
    cd_queue = []
    tx_queue = []
    
    cd_pin = None
    
    read_enabled = False
    max_size = 256
    
    state_machine = None
    
    def __init__(self, clk, cido, codi, cs, cd):
        self.cd_pin = cd
        
        self.state_machine = rp2.StateMachine(0, spi_sm, in_base=Pin("GP19"), jmp_pin=Pin("GP18"))
        self.state_machine.irq(self.handler)
        self.state_machine.active(1)
    
    def handler(self, sm):
        c = self.cd_pin.value()
        b = sm.get()
    
        if (not self.read_enabled) or len(self.rx_queue) > self.max_size:
            return
        
        self.cd_queue.append(c)
        self.rx_queue.append(b)

#ENDFILE
