#define __cplusplus 201103L //this is the one the arduino ide uses
#include <avr/io.h>
//#include <util/delay.h> //these are included in Arduino.h
//#include <avr/interrupt.h>
#include <arduino/Arduino.h>


volatile uint8_t led_intr_count = 0;
volatile uint8_t print_intr_count = 0;

void led_init()
{
    DDRB = (1 << DDB3); //set pb3 to output
    return;
}

void timer_init()
{
    sei();
    //set up timer0 for usb serial
    TCCR0A = (1 << WGM01) | (1 << WGM00); //fast pwm
}

int main(int argc, char* argv[])
{
    led_init();
    //init(); //init in wiring.c
    timer_init();
   
    #if defined(USBCON)
        USBDevice.attach();
    #endif
   
    Serial.begin(9600);
    
    while(1)
    {   
        Serial.println("hello world");
        PORTB ^=(1<<PORTB3);
        if (serialEventRun) serialEventRun();
        _delay_ms(1000);
    }

    return 0;
}
