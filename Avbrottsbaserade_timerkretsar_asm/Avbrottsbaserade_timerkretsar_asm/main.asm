; Lysdioder ansluten till pin 8 och 9.
.EQU LED1 = PORTB0
.EQU LED2 = PORTB1

; Knappar anslutna till pin 11, 12 och 13.
.EQU RESET_BUTTON = PORTB3
.EQU BUTTON1      = PORTB4
.EQU BUTTON2      = PORTB5

; Hur många interupts alla timers ska räkna upp till.
.EQU TIMER0_MAX_COUNT = 18
.EQU TIMER1_MAX_COUNT = 6
.EQU TIMER2_MAX_COUNT = 12

; Adresser till olika vektorer.
.EQU RESET_vect        = 0x00
.EQU PCINT0_vect       = 0x06
.EQU TIMER2_OVF_vect   = 0x12
.EQU TIMER1_COMPA_vect = 0x16
.EQU TIMER0_OVF_vect   = 0x20

; Deklarerar statiska variabler.
.DSEG
.ORG SRAM_START
counter0: .byte 1
counter1: .byte 1
counter2: .byte 1

; Kodsegementet.
.CSEG

; Alla vektorer som har fasta adresser läggs här.
.ORG RESET_vect
   RJMP main

.ORG PCINT0_vect
   RJMP ISR_PCINT0

.ORG TIMER2_OVF_vect
   RJMP ISR_TIMER2

.ORG TIMER1_COMPA_vect
   RJMP ISR_TIMER1

.ORG TIMER0_OVF_vect
   RJMP ISR_TIMER0

; PCI-avbrotten som sker på I/O-portarna B ligger här.
; Kollar om någon av knapparna är nedtryckt.
; Då avaktiveras PCI-Avbrott på I/O-portarna B och sedan hoppar man till respektive subrutin.
ISR_PCINT0:
   CLR R24
   STS PCICR, R24
   STS TIMSK0, R16
check_reset_button:
   IN R24, PINB
   ANDI R24, (1 << RESET_BUTTON)
   BREQ check_button1
   CALL system_reset
   RETI
check_button1:
   IN R24, PINB
   ANDI R24, (1 << BUTTON1)
   BREQ check_button2
   CALL timer1_toggle
   RETI
check_button2:
   IN R24, PINB
   ANDI R24, (1 << BUTTON2)
   BREQ check_button_end
check_button_end:
   RETI

; Alla timers och deras innehåll.
ISR_TIMER2:
   LDS R24, counter2
   INC R24
   CPI R24, TIMER2_MAX_COUNT
   BRLO TIMER2_end
   OUT PINB, R17
   CLR R24
TIMER2_end:
   STS counter2, R24
   RETI

ISR_TIMER1:
   LDS R24, counter1
   INC R24
   CPI R24, TIMER1_MAX_COUNT
   BRLO TIMER1_end
   OUT PINB, R16
   CLR R24
TIMER1_end:
   STS counter1, R24
   RETI

ISR_TIMER0:
   LDS R24, counter0
   INC R24
   CPI R24, TIMER0_MAX_COUNT
   BRLO TIMER0_end
   STS PCICR, R16
   CLR R24 
   STS TIMSK0, R24
TIMER0_end:
   STS counter0, R24
   RETI

; main.
main:
   CALL setup

; main loopen.
main_loop:
   RJMP main_loop

; Här görs alla förberdeleser inför programmets start.
setup:
   LDI R16, (1 << LED1) | (1 << LED2)
   OUT DDRB, R16
   LDI R24, (1 << BUTTON1) | (1 << BUTTON2) | (1 << RESET_BUTTON)
   OUT PORTB, R24
   LDI R16, (1 << LED1)
   LDI R17, (1 << LED2)
   LDI R18, (1 << RESET_BUTTON)
   LDI R19, (1 << BUTTON1)
   LDI R20, (1 << BUTTON2)

   SEI
   STS PCICR, R16
   STS PCMSK0, R24
   LDI R24, (1 << CS00) | (1 << CS02)
   OUT TCCR0B, R24
   LDI R24, (1 << CS10) | (1 << CS12) | (1 << WGM12)
   STS TCCR1B, R24
   LDI R24, high(256)
   STS OCR1AH, R24
   LDI R24, low(256)
   STS OCR1AL, R24

   LDI R24, (1 << CS20) | (1 << CS21) | (1 << CS22)
   STS TCCR2B, R24
   RET

; Togglar timer1
timer1_toggle:
   LDS R24, TIMSK1
   EOR R24, R17
   STS TIMSK1, R24
   CPI R24, 0
   BRNE timer1_toggle_end
   IN R24, PORTB
   ANDI R24, ~(1 << LED1)
   OUT PORTB, R24
timer1_toggle_end:
   CLR R24
   RET

; Togglar timer2
timer2_toggle:
   LDS R24, TIMSK2
   EOR R24, R16
   STS TIMSK2, R24
   CPI R24, 0
   BRNE timer2_toggle_end
   IN R24, PORTB
   ANDI R24, ~(1 << LED2)
   OUT PORTB, R24
timer2_toggle_end:
   RET

; Stänger av timer1 och 2. Släcker alla lysdioder. Nollställer räknarna.
system_reset:
   CLR R24
   STS TIMSK1, R24
   STS TIMSK2, R24
   STS counter0, R24
   STS counter1, R24
   STS counter2, R24
   IN R24, PORTB
   ANDI R24, ~((1 << LED1) | (1 << LED2))
   OUT PORTB, R24
   RET