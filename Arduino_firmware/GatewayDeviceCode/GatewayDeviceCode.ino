#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <SPI.h>
#include <LoRa.h>

// BLE UUIDs
#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "abcd1234-5678-90ab-cdef-1234567890ab"

// LoRa pins 
#define LORA_SS   5
#define LORA_RST  14
#define LORA_DI0  26
#define LORA_SCK  18
#define LORA_MISO 19
#define LORA_MOSI 23

// BLE variables 
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// LoRa tracking 
String lastPayload = "none,none,nofall,idle";
unsigned long lastReceived = 0;

// Timing 
unsigned long lastNotify = 0;

// BLE Callbacks 
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("BLE connected");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("BLE disconnected");
    delay(500);
    pServer->startAdvertising();
    Serial.println("BLE advertising restarted");
  }
};

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("ESP32 BLE + LoRa Gateway Starting...");

  // BLE Setup 
  BLEDevice::init("GatewayDevice");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->start();

  Serial.println("BLE ready");

  //  LoRa Setup 
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DI0);

  if (!LoRa.begin(915E6)) {
    Serial.println("LoRa init failed!");
    while (1);
  }

  Serial.println("LoRa ready");
}

void loop() {

  // Check LoRa 
  int packetSize = LoRa.parsePacket();

  if (packetSize) {
    String payload = "";

    while (LoRa.available()) {
      payload += (char)LoRa.read();
    }

    if (payload.length() > 0) {
      lastReceived = millis();
      lastPayload = payload;

      Serial.print("LoRa: ");
      Serial.println(payload);
    }
  }

  // BLE update 
  unsigned long now = millis();

  if (now - lastNotify >= 200) { // 5 updates/sec
    lastNotify = now;

    // Last update time 
    unsigned long lastUpdateSec = 0;
    if (lastReceived > 0) {
      lastUpdateSec = (now - lastReceived) / 1000;
    }

    // Cane connection
    bool caneConnection = (lastReceived > 0 && (now - lastReceived) <= 15000);

    String blePayload = lastPayload + "," +
                        String(lastUpdateSec) + "," +
                        (caneConnection ? "Connected" : "Disconnected");

    // Send BLE 
    if (deviceConnected) {
      pCharacteristic->setValue(blePayload.c_str());
      pCharacteristic->notify();

      Serial.print("BLE: ");
      Serial.println(blePayload);
    }
  }
}