int incomingByte = 0; // for incoming serial data
int solenoidPin = 11; //sets solenoid at location 11 on board
int isOpen = 0; 

void setup() {
  Serial.begin(9600); //establishes baud rate and opens serial port
  pinMode(solenoidPin, OUTPUT); //sets solenoid pin as output
  digitalWrite(solenoidPin, LOW);
}

void loop() {
  if (Serial.available()>0) {
    incomingByte = Serial.parseInt(); // reads incoming byte
    if (incomingByte>1){
      digitalWrite(solenoidPin,HIGH); //opens solenoid
      delay((unsigned long)incomingByte); //stays open for length of delay
      digitalWrite(solenoidPin, LOW); //solenoid closes

      Serial.print("I received: "); //say what you got
      Serial.println(incomingByte,DEC);
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
