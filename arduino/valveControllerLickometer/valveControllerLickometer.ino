#include <Wire.h>
#include "Adafruit_MPR121.h"

// You can have up to 4 on one i2c bus
Adafruit_MPR121 cap = Adafruit_MPR121();

int incomingByte = 0; // for incoming serial data
int solenoidPin = 11; //sets solenoid at location 11 on board
int isOpen = 0; 

// Keeps track of the last electrodes touched
// so we know when licks start and stop
uint16_t lasttouched = 0;
uint16_t currtouched = 0;
int LickOutPin = 8; //can add more pins if more electrodes connected
int delivering = 0;
long offTime = 0;
long currentTime;

void setup() {
  Serial.begin(9600); //establishes baud rate and opens serial port
  pinMode(solenoidPin, OUTPUT); //sets solenoid pin as output
  digitalWrite(solenoidPin, LOW);
  pinMode(LickOutPin, OUTPUT);

  // Lickometer startup
  // Default address is 0x5A, if tied to 3.3V its 0x5B
  // If tied to SDA its 0x5C and if SCL then 0x5D
  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 not found, check wiring?");
    while (1);
  }
  Serial.println("MPR121 found!");

 //how long does it wait for a signal from MATLAB (3 ms seems like plenty)
  Serial.setTimeout(5);
}  

void loop() {
  //if not already delivering reward
  if (delivering==0){
    if (Serial.available()>0) {
      incomingByte = Serial.parseInt(); // reads incoming byte
      if (incomingByte>1){
        digitalWrite(solenoidPin,HIGH); //opens solenoid
        delivering = 1;
        currentTime = (long)millis();
        offTime = currentTime+incomingByte;
        
        //Serial.print(millis());
        //Serial.print(" I received: "); //say what you 
        //Serial.println(incomingByte,DEC);
        //Serial.print("Off time: "); //say what you got
        //Serial.println(offTime);
      } else {
        if (incomingByte==1) { // the value sent was 1, this means toggle
          if (isOpen==0) {
            digitalWrite(solenoidPin,HIGH);
            isOpen=1;
          } else {
            digitalWrite(solenoidPin,LOW);
            isOpen=0;
          }
        }
      }
    }
  }

  if (delivering == 1) {
    currentTime = (long)millis();
    if (currentTime >= offTime) {
    //if (millis() >= 1) {
      digitalWrite(solenoidPin, LOW); //solenoid closes
      //Serial.print(millis());
      //Serial.println(" Delivered");
      delivering = 0;
    }
  }

  //check if sensor is touched
  currtouched = cap.touched();

  //sensor is on one right now
  for (uint8_t i=1; i<2; i++) { //change the maximum i if more electrodes added
    // it if *is* touched and *wasnt* touched before, alert!
    if ((currtouched & _BV(i)) && !(lasttouched & _BV(i)) ) {
      digitalWrite(LickOutPin, HIGH);
      Serial.print(millis()); Serial.print(" Lick on "); Serial.println(i);
    }
    // if it *was* touched and now *isnt*, alert!
    if (!(currtouched & _BV(i)) && (lasttouched & _BV(i)) ) {
      digitalWrite(LickOutPin, LOW);
      //Serial.print(millis()); Serial.print(" Lick off "); Serial.println(i);
    }
  }

  // reset our state
  lasttouched = currtouched;  
  
}
