#STARTFILE bargraph.py

from machine import Pin, Timer

leds = []
timer = Timer()
led_value = 0
led_index = 0

# operates a led bargraph
def init():
    # sestup pins
    for i in range(8):
        leds.append(Pin(f"GP{i + 6}", Pin.OUT))
    
    # create timer so we aren't driving all at once
    timer.init(mode=Timer.PERIODIC, freq=1024, callback=tcb)

def tcb(timer):
    global led_index
    global leds
    global led_value
    if led_index < 8:
        if led_index > 0:
            leds[led_index - 1].value(0)
        leds[led_index].value((led_value >> (7 - led_index)) & 1)
    elif led_index == 8:
        leds[7].value(0)
    
    led_index += 1
    if led_index >= 16:
        led_index = 0

#ENDFILE
