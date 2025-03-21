;;;-*- Mode: Lisp; Package: cl-user -*-

(in-package :cl-user)

; AVR

(defparameter *title-avr*
#"/* uLisp AVR Release ~a - www.ulisp.com
   David Johnson-Davies - www.technoblogy.com - ~a
   
   Licensed under the MIT license: https://opensource.org/licenses/MIT
*/"#)

(defparameter *header-avr* #"
// Lisp Library
const char LispLibrary[] PROGMEM = "";

// Compile options

#define checkoverflow
// #define resetautorun
#define printfreespace
// #define printgcs
// #define sdcardsupport
// #define lisplibrary
#define assemblerlist
// #define lineeditor
// #define vt100
// #define extensions

// Includes

// #include "LispLibrary.h"
#include <avr/sleep.h>
#include <setjmp.h>
#include <SPI.h>
#include <limits.h>

#if defined(sdcardsupport)
#include <SD.h>
#define SDSIZE 172
#else
#define SDSIZE 0
#endif"#)

(defparameter *workspace-avr* #"
// Platform specific settings

#define WORDALIGNED __attribute__((aligned (2)))
#define OBJECTALIGNED __attribute__((aligned (4)))
#define BUFFERSIZE 22                     /* longest builtin name + 1 */

#if defined(ARDUINO_AVR_MEGA2560)
  #include <EEPROM.h>
  #define WORKSPACESIZE (1344-SDSIZE)     /* Objects (4*bytes) */
  #define EEPROMSIZE 4096                 /* Bytes */
  #define STACKDIFF 320
  #define CPU_ATmega2560

#elif defined(__AVR_ATmega1284P__)
  #include "optiboot.h"
  #define WORKSPACESIZE (2944-SDSIZE)     /* Objects (4*bytes) */
//  #define EEPROMSIZE 4096                 /* Bytes */
  #define FLASHWRITESIZE 16384            /* Bytes */
  #define CODESIZE 96                     /* Bytes <= 256 */
  #define STACKDIFF 320
  #define CPU_ATmega1284P

#elif defined(__AVR_AVR128DA48__)
  #include <Flash.h>
  #define Serial Serial1
  #define WORKSPACESIZE (2920-SDSIZE)     /* Objects (4*bytes) */
  #define FLASHWRITESIZE 15872            /* Bytes */
  #define CODESIZE 96                     /* Bytes <= 512 */
  #define STACKDIFF 320
  #define CPU_AVR128DX48
  #define LED_BUILTIN 20

#elif defined(__AVR_AVR128DB48__)
  #include <Flash.h>
  #define Serial Serial3
  #define WORKSPACESIZE (2920-SDSIZE)     /* Objects (4*bytes) */
  #define FLASHWRITESIZE 15872            /* Bytes */
  #define CODESIZE 96                     /* Bytes <= 512 */
  #define STACKDIFF 320
  #define CPU_AVR128DX48
  #define LED_BUILTIN 20
  
#else
#error "Board not supported!"
#endif"#)

(defparameter *watchdog-avr* #"
// Watchdog

void watchdogenable (int interval) {
  int i = 5;
  while (interval) { interval = interval>>1; i++; }
  wdt_enable(i);
}

void watchdogreset () {
  wdt_reset();
}"#)


(defparameter *check-pins-avr* #"
// Check pins - these are board-specific not processor-specific

void checkanalogread (int pin) {
#if defined(ARDUINO_AVR_MEGA2560)
  if (!(pin>=0 && pin<=15)) error(invalidpin, number(pin));
#elif defined(__AVR_ATmega1284P__)
  if (!(pin>=0 && pin<=7)) error(invalidpin, number(pin));
#elif defined(__AVR_AVR128DA48__)
  if (!(pin>=22 && pin<=39)) error(invalidpin, number(pin));
#endif
}

void checkanalogwrite (int pin) {
#if defined(ARDUINO_AVR_MEGA2560)
  if (!((pin>=2 && pin<=13) || (pin>=44 && pin<=46))) error(invalidpin, number(pin));
#elif defined(__AVR_ATmega1284P__)
  if (!(pin==3 || pin==4 || pin==6 || pin==7 || (pin>=12 && pin<=15))) error(invalidpin, number(pin));
#elif defined(__AVR_AVR128DA48__)
  if (!((pin>=4 && pin<=5) || (pin>=8 && pin<=19) || (pin>=38 && pin<=39))) error(invalidpin, number(pin));
#endif
}"#)

(defparameter *note-avr* #"
// Note

#if defined(CPU_AVR128DX48)
const int scale[] PROGMEM = {4186,4435,4699,4978,5274,5588,5920,6272,6645,7040,7459,7902};
#else
const uint8_t scale[] PROGMEM = {239,226,213,201,190,179,169,160,151,142,134,127};
#endif

void playnote (int pin, int note, int octave) {
#if defined(CPU_ATmega2560)
  if (pin == 9) {
    DDRH = DDRH | 1<<DDH6; // PH6 (Arduino D9) as output
    TCCR2A = 0<<COM2A0 | 1<<COM2B0 | 2<<WGM20; // Toggle OC2B on match
  } else if (pin == 10) {
    DDRB = DDRB | 1<<DDB4; // PB4 (Arduino D10) as output
    TCCR2A = 1<<COM2A0 | 0<<COM2B0 | 2<<WGM20; // Toggle OC2A on match
  } else error(PSTR("only pins 9 and 10 supported"), number(pin));
  int oct = octave + note/12;
  int prescaler = 9 - oct;
  if (prescaler<3 || prescaler>6) error(PSTR("octave out of range"), number(oct));
  OCR2A = pgm_read_byte(&scale[note%12]) - 1;
  TCCR2B = 0<<WGM22 | prescaler<<CS20;

#elif defined(CPU_ATmega1284P)
  if (pin == 14) {
    DDRD = DDRD | 1<<DDD6; // PD6 (Arduino D14) as output
    TCCR2A = 0<<COM2A0 | 1<<COM2B0 | 2<<WGM20; // Toggle OC2B on match
  } else if (pin == 15) {
    DDRD = DDRD | 1<<DDD7; // PD7 (Arduino D15) as output
    TCCR2A = 1<<COM2A0 | 0<<COM2B0 | 2<<WGM20; // Toggle OC2A on match
  } else error(PSTR("only pins 14 and 15 supported"), number(pin));
  int oct = octave + note/12;
  int prescaler = 9 - oct;
  if (prescaler<3 || prescaler>6) error(PSTR("octave out of range"), number(oct));
  OCR2A = pgm_read_byte(&scale[note%12]) - 1;
  TCCR2B = 0<<WGM22 | prescaler<<CS20;

#elif defined(CPU_AVR128DX48)
  int oct = octave + note/12;
  int prescaler = 8 - oct;
  if (prescaler<0 || prescaler>8) error(PSTR("octave out of range"), number(oct));
  tone(pin, pgm_read_word(&scale[note%12])>>prescaler);
#endif
}

void nonote (int pin) {
#if defined(CPU_AVR128DX48)
  noTone(pin);
#else
  (void) pin;
  TCCR2B = 0<<WGM22 | 0<<CS20;
#endif
}"#)

(defparameter *sleep-avr* #"
// Sleep

#if defined(CPU_ATmega2560) || defined(CPU_ATmega1284P)
// Interrupt vector for sleep watchdog
ISR(WDT_vect) {
  WDTCSR |= 1<<WDIE;
}
#endif

void initsleep () {
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
}

void sleep () {
#if defined(CPU_ATmega2560) || defined(CPU_ATmega1284P)
  ADCSRA = ADCSRA & ~(1<<ADEN); // Turn off ADC
  delay(100);  // Give serial time to settle
  PRR0 = PRR0 | 1<<PRTIM0;  // Turn off Timer/Counter0
  sleep_enable();
  sleep_cpu();
  PRR0 = PRR0 & ~(1<<PRTIM0); // Turn on Timer/Counter0
  ADCSRA = ADCSRA | 1<<ADEN; // Turn on ADC
#endif
}

void doze (int secs) {
#if defined(CPU_ATmega2560) || defined(CPU_ATmega1284P)
  // Set up Watchdog timer for 1 Hz interrupt
  WDTCSR = 1<<WDCE | 1<<WDE;
  WDTCSR = 1<<WDIE | 6<<WDP0;     // 1 sec interrupt
  while (secs > 0) { sleep(); secs--; }
  WDTCSR = 1<<WDCE | 1<<WDE;     // Disable watchdog
  WDTCSR = 0;
#else
  delay(1000*secs);
#endif
}"#)

(defparameter *interrupts-avr* #"
// Interrupts

#if defined(CPU_ATmega2560)
#define NINTERRUPTS 8+1
#elif defined(CPU_ATmega1284P)
#define NINTERRUPTS 3+1
#endif

unsigned int InterruptCount[NINTERRUPTS];

void handleInterrupts () {
  if (tstflag(BUSY)) return;
  object *nullenv = NULL;
  setflag(BUSY);
  int ints, flag;
  cli(); flag = tstflag(INTERRUPT); clrflag(INTERRUPT); sei();
  if (flag) {
    for (int i=0; i<NINTERRUPTS; i++) {
      cli(); ints = InterruptCount[i]; InterruptCount[i] = 0; sei();
      if (ints) {
        object *pair = assoc(number(i),Events);
        object *arg = cons(number(ints), NULL);
        push(arg, GCStack);
        if (pair != NULL) apply(cdr(pair), arg, &nullenv);
        pop(GCStack);
      }
    }
  }
  clrflag(BUSY);
}

void interrupt (int n) {
  setflag(INTERRUPT);
  if (InterruptCount[n] < 0xFFFF) InterruptCount[n]++;
}

//ISR(TIMER1_OVF_vect) { interrupt(0); }
ISR(INT0_vect) { interrupt(0); }
ISR(INT1_vect) { interrupt(1); }
#if defined(CPU_ATmega1284P)
ISR(INT2_vect) { interrupt(2); }
#elif defined(CPU_ATmega2560)
ISR(INT2_vect) { interrupt(2); }
ISR(INT3_vect) { interrupt(3); }
ISR(INT4_vect) { interrupt(4); }
ISR(INT5_vect) { interrupt(5); }
ISR(INT6_vect) { interrupt(6); }
ISR(INT7_vect) { interrupt(7); }
#endif"#)

(defparameter *keywords-avr*
  '((nil
     ((NIL LED_BUILTIN)
      (DIGITALWRITE HIGH LOW)
      (PINMODE INPUT INPUT_PULLUP OUTPUT)))
    ("CPU_ATmega1284P"
     ((ANALOGREFERENCE DEFAULT INTERNAL1V1 INTERNAL2V56 EXTERNAL)
      (REGISTER PORTA DDRA PINA PORTB DDRB PINB PORTC DDRC PINC PORTD DDRD PIND)))
    ("CPU_ATmega2560"
     ((ANALOGREFERENCE DEFAULT INTERNAL1V1 INTERNAL2V56 EXTERNAL)
      (REGISTER PORTA DDRA PINA PORTB DDRB PINB PORTC DDRC PINC PORTD DDRD PIND 
                PORTE DDRE PINE PORTF DDRF PINF PORTG DDRG PING PORTJ DDRJ PINJ)))
    ("CPU_AVR128DX48"
     ((ANALOGREFERENCE DEFAULT VDD INTERNAL1V024 INTERNAL2V048 INTERNAL4V096 INTERNAL2V5 EXTERNAL)
      (ANALOGREAD ADC_DAC0 ADC_TEMPERATURE)
      (REGISTER  PORTA_DIR PORTA_OUT PORTA_IN PORTB_DIR PORTB_OUT PORTB_IN PORTC_DIR PORTC_OUT PORTC_IN
                 PORTD_DIR PORTD_OUT PORTD_IN PORTE_DIR PORTE_OUT PORTE_IN PORTF_DIR PORTF_OUT PORTF_IN)))))