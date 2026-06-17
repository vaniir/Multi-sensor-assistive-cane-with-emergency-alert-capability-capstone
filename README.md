# [Project Name] - Multi Sensor Assistive Cane with Emergency Alert Capability

-An Engineering capstone project showcasing an end-to-end data pipeline bridging embedded Esp32 hardware and flutter mobile app

## Data Architecture & Pipeline

## Edge Data Pipeline & Transformations

 [ Assistive Cane Sensors ] - ( Local State Reduction ) --> [ LoRa Transmitter ]
                                                                │
                                                (Compressed Payload)
                                                                |
                                                                ▼
 [ Flutter App ] <-- ( Enriched BLE Stream )-[ GatewayDevice/Receiver ]
                                                        │
                                             (Data Enrichment / Heartbeat)

## Data Engineering Highlights

**Multi-Protocol Pipeline:**
Multi-Protocol Telemetry Pipeline: Engineered a multi-stage IoT data pipeline bridging long-range telemetry (LoRa) and local high-frequency streams (BLE) across independent embedded nodes

**Edge Data Compaction:**
Optimized network bandwidth by processing continuous raw sensor signals (accelerometer, time-of-flight, and analog telemetry) directly on the edge microcontroller, reducing complex data footprints down to compact status flags before transmission

**In-Flight Data Enrichment:**
Programmed the gateway node to evaluate data freshness and append diagnostic health metrics (system heartbeat and payload latency calculations) to the data stream dynamically before delivering it to the consumer application

## Tech Stack

**Languages:** C/C++ (Embedded Firmware), Dart (Mobile Client)
**Frameworks & Libraries:** Flutter, Arduino Core SDK
**Wireless Protocols (Data Transport):** LoRa (Long Range RF), BLE (Bluetooth Low Energy)
**Development Tools:** Arduino IDE, VS Code

## Repository Structure

* `/Arduino_firmware/CaneDeviceCode` - Edge collection node; extracts raw multi-sensor telemetry, runs local state-reduction logic, and broadcasts optimized string payloads via LoRa

* `/Arduino_firmware/GatewayDeviceCode` - Network brokerage node; ingests edge radio packets, enriches the payload with telemetry health tracking data, and acts as a local BLE data publisher

* `/flutter_app/lib/main` - Downstream data consumer; handles UI binding and visualization of the processed, enriched pipeline stream

* `/flutter_app/lib/ble_code` - Ingestion driver; interfaces with the gateway broker to ingest the real-time serialized byte stream over Bluetooth Low Energy

---

## Hardware & Implementation Notes

Because this pipeline relies on a dedicated physical architecture, the code cannot be executed locally without the following edge components:
* **Transmitter Node:** Microcontroller configured with a LoRa Transceiver module.
* **Gateway Node:** Microcontroller acting as a local network broker equipped with both LoRa and Esp32 for Bluetooth Low Energy (BLE) peripherals.
* **Client Device:** A BLE-enabled mobile device capable of running the Flutter environment.