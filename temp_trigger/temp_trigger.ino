/*
 * temp_trigger.ino
 * 
 * This project is for using resistance-based tempurature sensors to control a trigger
 * In my specific use case, this trigger turns on a driveway heater when the sensors drop below freezing
 * 
 * SEE THE DATASHEET OF YOUR SPECIFIC TEMPERATURE SENSOR FOR OHM CONVERSIONS
 */

// Analog reading pin for temp sensor and digital write pin for the heater trigger
int temp_sensor_1 = A0, temp_sensor_2 = A1;
int trigger = 2;

void setup() {
  pinMode(temp_sensor_1, INPUT);
  pinMode(temp_sensor_2, INPUT);
  pinMode(trigger, OUTPUT);
}

/*
 * Ohm's law for voltage splitters: Vo = Vi(Rg/(Rv+Rg))
 * Our Rg (resistance to ground) is 22k ohms
 * I chose this value because the range of readings we care about from the tempurature sensor datasheet is 21k - 35k ohms (5 degrees to -5 degrees celcius)
 * 
 * The analog pins read values 0-1023 in direct accordance with the operating voltage (5v in our case)
 * We recieve an analog value and take a fraction in relation to that range. This will be the same fraction from the Ohm's law equation above
 * A little bit of algebra gives us the resistance in the tempurature sensor: Rv = (Rg/<fraction>) - Rg
 * 
 * According to the temp sensor datasheet, the resistance at 0 degrees celsius is about 27k ohms
 */
bool is_freezing(int sensor) {
  float fraction = analogRead(sensor)/1023.0;
  int ohms = (22000.0/fraction) - 22000;
  return ohms >= 27000;
}

void loop() {

  // If both sensors are below freezing, turn on the heater
  if(is_freezing(temp_sensor_1) && is_freezing(temp_sensor_2)) digitalWrite(trigger, HIGH);
  else digitalWrite(trigger, LOW);
  
  delay(500);
}
