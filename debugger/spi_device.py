#STARTFILE spi_device.py

# The native SPI libraries are all bus controllers, not devices
# Therefore we have to do it ourselves.

from machine import Pin
import rp2

#import bargraph

class SPIDevice:
    clk_pin = None
    cido_pin = None
    codi_pin = None
    cs_pin = None
    cd_pin = None
    
    rx_queue = []
    tx_queue = []
    
    read_enabled = False

    def __init__(self, clk, cido, codi, cs, cd):
        self.clk_pin = Pin(clk, mode=Pin.IN)
        self.cido_pin = Pin(cido, mode=Pin.IN)
        self.codi_pin = Pin(codi, mode=Pin.IN)
        self.cs_pin = Pin(cs, mode=Pin.IN)
        self.cd_pin = Pin(cd, mode=Pin.IN)
        
        #bargraph.init()
        
        self.cs_pin.irq(self.handler, Pin.IRQ_FALLING)
    
    def handler(self, pin):
        if not self.read_enabled:
            return
    
        self.wait_for(self.clk_pin, 1)
        b = self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.wait_for(self.clk_pin, 0)
        self.wait_for(self.clk_pin, 1)
        b = (b << 1) | self.codi_pin.value()
        
        self.rx_queue.append(b)
        #bargraph.led_value = b
        #print(f"R: {b:02X} {len(self.rx_queue)} {self.cd_pin.value()}")
    
    def wait_for(self, pin, state):
        while True:
            if(pin.value() == state):
                return

#ENDFILE
