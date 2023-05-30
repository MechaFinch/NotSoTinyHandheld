#include <Adafruit_ILI9341.h>

#include <SPI.h>

/*
 * Debug Monitor
 * Program for monitoring the NST handheld
 * To operate, the display is rewired to the arduino per its library and the arduino is wired as SPI
 * device 0 in its place. The SPI interface on the handheld is set to output debug information
 */

// pins to control the 320x240 display. we are the controller.
#define TFT_DC    9
#define TFT_CS    10
#define TFT_CODI  11
#define TFT_CIDO  12
#define TFT_CLK   13
#define USE_TFT

// pins to control the 14x2 character LCD
#define LCD_CLK 11
#define LCD_SER 10
#define LCD_DC  9
#define LCD_E   8
//#define USE_LCD

// pins to recieve debug info. we are the device.
#define NST_CODI  7
#define NST_CIDO  6
#define NST_DC    5
#define NST_CS    4
#define NST_CLK   3

#define MASK_DC   0b00001000
#define MASK_CS   0b00010000
#define MASK_CODI 0b10000000
#define MASK_CLK  0b00000100

#define LCDCMD_CLEAR_DISPLAY  0b00000001
#define LCDCMD_RETURN_HOME    0b00000010
#define LCDCMD_MODE_SET       0b00000100
#define LCDCMD_DISPLAY_ONOFF  0b00001000
#define LCDCMD_SHIFT          0b00010000
#define LCDCMD_FUNCTION       0b00100000
#define LCDCMD_CGRAM          0b01000000
#define LCDCMD_DDRAM          0b10000000

#ifdef USE_TFT
Adafruit_ILI9341 tft = Adafruit_ILI9341(TFT_CS, TFT_DC);
#endif

// debug data
struct nst_debug_data_t {
  // registers
  uint32_t IP;
  uint32_t BP;
  uint32_t _SP;

  uint16_t A;
  uint16_t B;
  uint16_t C;
  uint16_t D;
  uint16_t I;
  uint16_t J;
  uint16_t K;
  uint16_t L;

  uint16_t F;
  uint16_t PF;

  // current instruction
  uint8_t OOP;
  uint8_t COP;
  uint8_t RIM;
  uint8_t BIO;
  uint32_t IMM;
  uint8_t EI8;

  // cycle & instruction counts
  uint32_t ICOUNT;
  uint32_t ECOUNT;
  uint32_t MCOUNT;
};

void setup() {
  #ifdef USE_TFT
  tft.begin();
  #endif

  // pins
  pinMode(NST_DC, INPUT);
  pinMode(NST_CS, INPUT);
  pinMode(NST_CODI, INPUT);
  pinMode(NST_CIDO, OUTPUT);
  pinMode(NST_CLK, INPUT);

  #ifdef USE_LCD
  pinMode(LCD_CLK, OUTPUT);
  pinMode(LCD_SER, OUTPUT);
  pinMode(LCD_DC, OUTPUT);
  pinMode(LCD_E, OUTPUT);

  digitalWrite(LCD_E, HIGH);
  #endif

  #ifdef USE_TFT
  tft.setTextColor(ILI9341_WHITE, ILI9341_BLACK);
  tft.setTextSize(1);
  tft.setRotation(3);
  tft.fillRect(0, 0, 320, 240, ILI9341_BLACK);

  tft.setCursor(0, 0);
  tft.println("Processor State");
  tft.println("A    B    C    D\n\n");
  tft.println("I    J    K    L\n\n");
  tft.println("F    PF\n\n");
  tft.println("IP       BP       SP\n\n");
  tft.println("OOP COP RIM BIO IMM      EI8\n\n\n");
  tft.println("Instruction Count:     ");
  tft.println("Execution Clock Count: ");
  tft.println("Memory Clock Count:    ");
  #endif
}

/*
nst_debug_data_t data = {
    0xABCDEF01, 0x98765432, 0x23894579,
    0x1234, 0x2345, 0x3456, 0x4567,
    0x9876, 0x8765, 0x7654, 0x6543,
    0x3984, 0x1329,
    0x53, 0x53, 0xF3, 0x90, 0x21436576, 0xEF,
    56783, 109343, 83920
  };
*/

void loop() {
  // read debug data
  nst_debug_data_t data = read_debug();

  // write debug data
  #ifdef USE_LCD

  #endif

  #ifdef USE_TFT
  //tft.fillRect(0, 0, 200, 150, ILI9341_BLACK);
  setCursorChars(0, 2);
  print_hex(data.A, 4);
  setCursorChars(5, 2);
  print_hex(data.B, 4);
  setCursorChars(10, 2);
  print_hex(data.C, 4);
  setCursorChars(15, 2);
  print_hex(data.D, 4);

  setCursorChars(0, 5);
  print_hex(data.I, 4);
  setCursorChars(5, 5);
  print_hex(data.J, 4);
  setCursorChars(10, 5);
  print_hex(data.K, 4);
  setCursorChars(15, 5);
  print_hex(data.L, 4);

  setCursorChars(0, 8);
  print_hex(data.F, 4);
  setCursorChars(5, 8);
  print_hex(data.PF, 4);
  
  setCursorChars(0, 11);
  print_hex(data.IP, 8);
  setCursorChars(9, 11);
  print_hex(data.BP, 8);
  setCursorChars(18, 11);
  print_hex(data._SP, 8);
  
  setCursorChars(0, 14);
  print_hex(data.OOP, 2);
  setCursorChars(4, 14);
  print_hex(data.COP, 2);
  setCursorChars(8, 14);
  print_hex(data.RIM, 2);
  setCursorChars(12, 14);
  print_hex(data.BIO, 2);
  setCursorChars(16, 14);
  print_hex(data.IMM, 8);
  setCursorChars(25, 14);
  print_hex(data.EI8, 2);

  setCursorChars(24, 17);
  print_hex(data.ICOUNT, 8);

  setCursorChars(24, 18);
  print_hex(data.ECOUNT, 8);

  setCursorChars(24, 19);
  print_hex(data.MCOUNT, 8);
  #endif
}

#ifdef USE_LCD
void send_command(uint8_t command) {
  
  if(command == LCDCMD_CLEAR_DISPLAY || command == LCDCMD_RETURN_HOME) {
    delayMicroseconds(1520);
  } else {
    delayMicroseconds(37);
  }
}

void send_data(uint8_t data) {
  
  delayMicroseconds(37);
}

void send_bits(uint8_t bits) {
  // MSB first
  for(int i = 0; i < 8; i++) {
    //digitalWrite(LCD_SER, 
  }
}
#endif

#ifdef USE_TFT
void setCursorChars(int16_t x, int16_t y) {
  tft.setCursor(x * 6, y * 8);
}

void print_hex(uint32_t val, int len) {
  for(int i = len - 1; i >= 0; i--) {
    uint32_t trimmed = (val >> (i * 4)) & 0xF;
    tft.print(trimmed, HEX);
  }
}
#endif

uint8_t buffer[53];

// read full debug data
nst_debug_data_t read_debug() {
  // DC will be low for IP
  read_53_bytes();

  // read each field
  uint32_t ip = (buffer[3] << 8) | buffer[2];
  ip = (ip << 16) | (((buffer[1] << 8) | buffer[0]) & 0xFFFF);

  uint32_t bp = (buffer[7] << 8) | buffer[6];
  bp = (bp << 16) | (((buffer[5] << 8) | buffer[4]) & 0xFFFF);

  uint32_t sp = (buffer[11] << 8) | buffer[10];
  sp = (sp << 16) | (((buffer[9] << 8) | buffer[8]) & 0xFFFF);

  uint16_t a = (buffer[13] << 8) | buffer[12];

  uint16_t b = (buffer[15] << 8) | buffer[14];

  uint16_t c = (buffer[17] << 8) | buffer[16];

  uint16_t d = (buffer[19] << 8) | buffer[18];

  uint16_t i = (buffer[21] << 8) | buffer[20];

  uint16_t j = (buffer[23] << 8) | buffer[22];

  uint16_t k = (buffer[25] << 8) | buffer[24];

  uint16_t l = (buffer[27] << 8) | buffer[26];

  uint16_t f = (buffer[29] << 8) | buffer[28];

  uint16_t pf = (buffer[31] << 8) | buffer[30];

  uint8_t i_oop = buffer[32];
  uint8_t i_cop = buffer[33];
  uint8_t i_rim = buffer[34];
  uint8_t i_bio = buffer[35];

  uint32_t i_imm = (buffer[39] << 8) | buffer[38];
  i_imm = (i_imm << 16) | (((buffer[37] << 8) | buffer[36]) & 0xFFFF);

  uint8_t i_ei8 = buffer[40];

  uint32_t icount = (buffer[44] << 8) | buffer[43];
  icount = (icount << 16) | (((buffer[42] << 8) | buffer[41]) & 0xFFFF);

  uint32_t ecount = (buffer[48] << 8) | buffer[47];
  ecount = (ecount << 16) | (((buffer[46] << 8) | buffer[45]) & 0xFFFF);

  uint32_t mcount = (buffer[52] << 8) | buffer[51];
  mcount = (mcount << 16) | (((buffer[50] << 8) | buffer[49]) & 0xFFFF);

  nst_debug_data_t data = {
    ip, bp, sp,
    a, b, c, d, i, j, k, l,
    f, pf,
    i_oop, i_cop,
    i_rim, i_bio,
    i_imm, i_ei8,
    icount, ecount, mcount
  };

  return data;
}

void read_53_bytes() {
  // wait on cd
  //while(PIND & NST_DC);
  while(digitalRead(NST_DC));
  
  for(int i = 0; i < 53; i++) {
    buffer[i] = read_byte();
  }
}

uint8_t read_byte() {
  uint8_t b = 0;

  for(int i = 0; i < 8; i++) {
    // wait for rising edge
    //while(!(PIND & NST_CLK));
    while(!digitalRead(NST_CLK));

    //b = (b << 1) | (PIND >> NST_CODI);
    b = (b << 1) | digitalRead(NST_CODI);

    // wait for falling edge
    //while(PIND & NST_CLK);
    while(digitalRead(NST_CLK));
  }

  return b;
}
