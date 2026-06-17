#include <Wire.h>
#include <VL53L1X.h>
#include <MPU6050.h>
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>
#include <SPI.h>
#include <LoRa.h>

// LoRa pins
#define LORA_SS   5
#define LORA_RST  14
#define LORA_DI0  32
#define LORA_SCK  18
#define LORA_MISO 19
#define LORA_MOSI 23

// initialize tof and accelerometer
VL53L1X tof;
MPU6050 mpu;

// GPS
TinyGPSPlus gps;
HardwareSerial SerialGPS(2);
#define GPS_RX 34 

double lat = 0.0;
double lng = 0.0;

// Water sensors
#define WATER_PIN 33

// Night light
#define AMBIENT_SENSOR 35
#define NIGHT_LIGHT 17

// haptic feedback
#define MOTOR_PIN 15
#define POT_PIN 4
unsigned long previousMillis = 0;
const int pulseInterval = 200;
bool motorState = false;

// fall detection variables
unsigned long fallStartTime = 0;
bool fallInProgress = false;
const unsigned long fallDuration = 5000; 

// activity detection
float lastAngle = 0;
unsigned long lastMovementTime = 0;
const unsigned long idleTime = 3000;

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);

  SerialGPS.begin(9600, SERIAL_8N1, GPS_RX, -1);

  pinMode(WATER_PIN, INPUT);
  pinMode(MOTOR_PIN, OUTPUT);
  pinMode(AMBIENT_SENSOR, INPUT);
  pinMode(NIGHT_LIGHT, OUTPUT);
  delay(500);

  Serial.println("Starting sensors...");

  tof.setTimeout(500);

  if (!tof.init()) {
    Serial.println("Failed to detect tof!");
    while (1);
  }

  tof.setDistanceMode(VL53L1X::Long);
  tof.setMeasurementTimingBudget(50000);
  tof.startContinuous(50);

  Serial.println("tof ready!");

  Serial.println("Starting MPU6050...");
  mpu.initialize();

  if (!mpu.testConnection()) {
    Serial.println("MPU6050 connection failed");
  } else {
    Serial.println("MPU6050 ready");
  }

  // LoRa setup
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DI0);

  if (!LoRa.begin(915E6)) {
    Serial.println("LoRa init failed!");
  }
  Serial.println("LoRa ready!");
}

void loop() {

  // GPS reading
  unsigned long gpsStart = millis();
  while (millis() - gpsStart < 100) {
    while (SerialGPS.available()) {
      gps.encode(SerialGPS.read());
    }
  }

  // Store last valid GPS
  if (gps.location.isValid()) {
    lat = gps.location.lat();
    lng = gps.location.lng();

    Serial.print("Latitude: ");
    Serial.println(lat, 6);
    Serial.print("Longitude: ");
    Serial.println(lng, 6);
  }

  // Sensors
  int distance = tof.read();
  int wet = analogRead(WATER_PIN);
  int lighting = analogRead(AMBIENT_SENSOR);

  int potValue = analogRead(POT_PIN);
  int pwmValue = map(potValue, 0, 4095, 0, 255);

  Serial.print("Distance: ");
  Serial.print(distance);
  Serial.println(" mm");

  Serial.print("Wet Surface: ");
  Serial.println(wet);

  Serial.print("Light level: ");
  Serial.println(lighting);

  if (tof.timeoutOccurred()) {
    Serial.println("Sensor timeout");
  }

  // Accelerometer
  int16_t ax, ay, az;
  mpu.getAcceleration(&ax, &ay, &az);

  float angle = atan2(ax, az) * 180 / PI;
  Serial.print(angle);
  Serial.println(" degree");

  // Activity detection
  if (abs(angle - lastAngle) > 3) {
    lastMovementTime = millis();
    Serial.println("System Active");
  }
  lastAngle = angle;

  bool active = (!fallInProgress && millis() - lastMovementTime <= idleTime);

  if (!fallInProgress && millis() - lastMovementTime > idleTime) {
    Serial.println("System Idle");
  }

  // Fall detection
  bool fallDetected = false;
  if (abs(angle) < 10) {
    if (!fallInProgress) fallStartTime = millis();
    fallInProgress = true;
    if (millis() - fallStartTime >= fallDuration) {
      Serial.println("Fall Detected");
      fallDetected = true;
    }
  } else {
    fallInProgress = false;
  }

  // Feedback
  if (distance <= 800) {
    analogWrite(MOTOR_PIN, pwmValue);
  }
  else if (wet <= 3500) {  
    unsigned long currentMillis = millis();
    if (currentMillis - previousMillis >= pulseInterval) {
      previousMillis = currentMillis;
      motorState = !motorState;
      if (motorState) analogWrite(MOTOR_PIN, pwmValue);
      else analogWrite(MOTOR_PIN, 0);
    }
  }
  else {
    analogWrite(MOTOR_PIN, 0);
  }

  // Night light
  if (lighting <= 200) {
    digitalWrite(NIGHT_LIGHT, HIGH);
  } else {
    digitalWrite(NIGHT_LIGHT, LOW);
  }

  sendLoRaData(fallDetected, active);

  delay(500);
}

void sendLoRaData(bool fallDetected, bool active) {
  String payload = "";

  // Use stored GPS
  if (lat != 0.0 && lng != 0.0)
    payload += String(lat, 6) + "," + String(lng, 6);
  else
    payload += "none,none";

  payload += ",";
  payload += fallDetected ? "fall" : "nofall";
  payload += ",";
  payload += active ? "active" : "idle";

  LoRa.beginPacket();
  LoRa.print(payload);
  LoRa.endPacket();

  Serial.print("LoRa sent: ");
  Serial.println(payload);
}