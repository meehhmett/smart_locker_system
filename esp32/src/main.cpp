#include <Arduino.h>

#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// Declerations

void lockLocker();
void unlockLocker();
void checkRFID();
void writeServo(int angle);
void setColor(int r, int g, int b);
void beep(int count);
String uidToString();

String firebaseGet(String path);
void firebaseSet(String path, String value);
void firebaseSetBool(String path, bool value);

 
// Organization ve esp locker id's
String organizationId = "maltepe-university";
String lockerId = "locker1";



#define WIFI_SSID "Your Wifi -- 5G is not working-- "
#define WIFI_PASSWORD "Your wifi password"

//DATA ROOT URL
#define DATABASE_URL "https://smart-locker-84032-default-rtdb.europe-west1.firebasedatabase.app"

String allowedUID = "0";

unsigned long lastFirebaseCheck = 0;

bool lastDoorClosed = false;
unsigned long lastDoorCheck = 0;
const unsigned long doorCheckInterval = 300;

#define SS_PIN 5
#define RST_PIN 22

MFRC522 rfid(SS_PIN, RST_PIN);


const int servoPin = 13;
const int freq = 50; // Siyanl frekansi mesela 50hz servo motorlar 5000 hz ledler icin
const int resolution = 16; // 0 ile 2^16 arası değerler
// 50 hz = 20 ms dir 20 ms = 20*100 = 20000 us eder
//resolution = 16 dedik yani 2^16 eder bu da 65535 tir
// duty = map tan gelen değer *   (65535 / 20000) dir yani resolution 8 yapsaydik ve 100 hz alsaydik 8 = 2^8 = 255 olcakti 100hz de 10ms yani
// 10000 us olcakti o zaman duty = mapten gelen değer * 255/10000 olurdu.


const int buzzerPin = 14;
const int doorSensorPin = 33;

const int redPin = 25;
const int greenPin = 26;
const int bluePin = 27;


bool lockerLocked = true;


//DEBUG RFUID


void setup() {
  Serial.begin(115200);

  // WIFI SYSTEM UP
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi connected");

  //RFID SYSTEM
  SPI.begin(18, 19, 23, 5);
  rfid.PCD_Init();
  Serial.println("RFID system ready");

  //servopwm
  ledcSetup(0, 50, 16);
  ledcAttachPin(servoPin, 0);  // servopin,freq,resolution

  //RGB
  pinMode(redPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  pinMode(bluePin, OUTPUT);

  setColor(0,0,0);
  delay(300);
  lockLocker();

  //BUZZER
  pinMode(buzzerPin, OUTPUT);

  //BUTTON
  pinMode(doorSensorPin, INPUT_PULLUP);
  lastDoorClosed = digitalRead(doorSensorPin) == LOW;

  lockLocker();
}

void loop() {

  if (millis() - lastFirebaseCheck > 3000) {

    allowedUID = firebaseGet(
  "organizations/" + organizationId + "/lockers/" + lockerId + "/allowedRfidUID"
  );

    Serial.print("Firebase UID: ");
    Serial.println(allowedUID);
    String unlockRequest = firebaseGet(
  "organizations/" + organizationId + "/lockers/" + lockerId + "/unlockRequest"
  );

  Serial.print("Unlock Request: ");
  Serial.println(unlockRequest);

  bool doorClosed = digitalRead(doorSensorPin) == LOW;

  if (doorClosed) {
    Serial.println("KAPI KAPALI");
  } else {
    Serial.println("KAPI ACIK");
  }


  

  if (unlockRequest == "true") {
    Serial.println("App unlock request received");

    unlockLocker();

    firebaseSetBool(
      "organizations/" + organizationId + "/lockers/" + lockerId + "/unlockRequest",
      false
    );
  }
  String lockState = firebaseGet(
  "organizations/" + organizationId + "/lockers/" + lockerId + "/lockState"
);

if (lockState == "locked" && !lockerLocked) {
  lockLocker();
}

if (lockState == "unlocked" && lockerLocked) {
  unlockLocker();
}

    lastFirebaseCheck = millis();
  }



  checkRFID();

  if (millis() - lastDoorCheck > doorCheckInterval) {
  lastDoorCheck = millis();

  bool doorClosed = digitalRead(doorSensorPin) == LOW;

  if (doorClosed != lastDoorClosed) {
    lastDoorClosed = doorClosed;

    if (doorClosed) {
      Serial.println("KAPI KAPANDI -> SERVO KILITLENIYOR");

      firebaseSet(
        "organizations/" + organizationId + "/lockers/" + lockerId + "/doorState",
        "closed"
      );

      firebaseSetBool(
        "organizations/" + organizationId + "/lockers/" + lockerId + "/doorClosed",
        true
      );

      if (!lockerLocked) {
        lockLocker();
      }

    } else {
      Serial.println("KAPI ACIK");

      firebaseSet(
        "organizations/" + organizationId + "/lockers/" + lockerId + "/doorState",
        "open"
      );

      firebaseSetBool(
        "organizations/" + organizationId + "/lockers/" + lockerId + "/doorClosed",
        false
      );
    }
  }
}

delay(50);
}


void lockLocker() {
  lockerLocked = true;
  writeServo(0);
  setColor(0, 0, 255);
  beep(1);
  firebaseSet(
  "organizations/"+ organizationId +"/lockers/" + lockerId + "/lockState",
  "locked"
  );
  Serial.println("Locker locked");
}

void unlockLocker() {
  lockerLocked = false;
  writeServo(90);
  setColor(0, 255, 0);
  beep(2);
  firebaseSet(
  "organizations/"+ organizationId +"/lockers/" + lockerId + "/lockState",
  "unlocked"
  );
  Serial.println("Locker unlocked");
}

void writeServo(int angle) {
  int us = map(angle, 0, 180, 500, 2400);
  int duty = us * 65535 / 20000;
  ledcWrite(servoPin, duty);
}

void setColor(int r, int g, int b) {
  analogWrite(redPin, 255 - r);
  analogWrite(greenPin, 255 - g);
  analogWrite(bluePin, 255 - b);
}

void beep(int count) {
  for (int i = 0; i < count; i++) {
    digitalWrite(buzzerPin, HIGH);
    delay(150);
    digitalWrite(buzzerPin, LOW);
    delay(150);
  }
}

void checkRFID() {

  if (!rfid.PICC_IsNewCardPresent()) return;

  if (!rfid.PICC_ReadCardSerial()) return;

  String scannedUID = uidToString();

  Serial.print("Scanned UID: [");
  Serial.print(scannedUID);
  Serial.println("]");

  Serial.print("Allowed UID: [");
  Serial.print(allowedUID);
  Serial.println("]");

  if (scannedUID == allowedUID && allowedUID != "0" && allowedUID != "null" && allowedUID != "") {

    Serial.println("Correct card -> Unlocking");

    unlockLocker();

  } else {

    Serial.println("Wrong card -> Alarm");

    setColor(255, 0, 0);

    beep(5);

    if (lockerLocked) {
      setColor(0, 0, 255);
    } else {
      setColor(0, 255, 0);
    }
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

String uidToString() {
  String uid = "";

  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }

  uid.toUpperCase();
  return uid;
}

void firebaseSet(String path, String value) {

  HTTPClient http;

  String url = String(DATABASE_URL) + "/" + path + ".json";

  http.begin(url);

  http.addHeader("Content-Type", "application/json");

  String body = "\"" + value + "\"";

  int httpCode = http.PUT(body);

  Serial.print("Firebase SET ");
  Serial.print(path);
  Serial.print(" -> ");
  Serial.println(httpCode);

  http.end();
}

void firebaseSetBool(String path, bool value) {
  HTTPClient http;

  String url = String(DATABASE_URL) + "/" + path + ".json";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  String body = value ? "true" : "false";

  int httpCode = http.PUT(body);

  Serial.print("Firebase SET BOOL ");
  Serial.print(path);
  Serial.print(" -> ");
  Serial.println(httpCode);

  http.end();
}

String firebaseGet(String path) {

  HTTPClient http;

  String url = String(DATABASE_URL) + "/" + path + ".json";

  http.begin(url);

  int httpCode = http.GET();

  if (httpCode > 0) {

    String payload = http.getString();

    payload.replace("\"", "");

    http.end();

    return payload;
  }

  http.end();

  return "";
}