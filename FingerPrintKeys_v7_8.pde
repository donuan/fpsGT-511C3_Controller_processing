/* 
 Processing sketch by Hannes Andersson for controlling the sparkfun GT-11C3 Fingerprint
 Scanner via a USB to Serial adapter. 
 http://donuan.tv
 https://github.com/donuan
 
 Phase 0: INACTIVE
 Phase 1: Standby, checking if a finger is pressed (key 1)
 Phase 2: Take Photo (key 2)
 Phase 3: Ask for photo (key 3)
 Phase 4: Store photo (key 4)
 
 RESET: Key Q
 
 Keys for manual control: 
 
 //O = led On (NOT ACTIVE, USE: 1 OR SPACEBAR)
 //P = Led Off (NOT ACTIVE, USE: 0)
 F = asks if finger is present
 C = captures a photo
 D = deletes all stored photos
 G = Get Image
 R = Get Raw Image
 
 */

import processing.serial.*;
import codeanticode.syphon.*;


PImage img = createImage(258, 202, RGB);

Serial serial_port;

PrintWriter output; 

int phase = 0; //INACTIVE
int oldPhase;
int xPix = 0;
int yPix = 0;
int baudRate = 9600;

PFont pixelmix;
int count = 0; //counter for filling the inBuffer byte array
int photoCount;
int textOp = 0;
int errorTime = 100; 
long lastTime; //timer
long waitCount;
byte[] inBuffer = new byte[12]; //byte array for storing incoming answers
char[] photoBuffer = new char[52116];
byte[] photoBufferByte = new byte[52116];
byte[] photo = new byte[52116];
byte rxByte;
String hexByte;
boolean answer; //is the answer yes or no
boolean fingerAsk; //are we asking about the fingerPressedState
boolean fotoRequest = false; //are we asking for the photo
boolean ledOn; //is the led on (not used for any real communication with the device
boolean oldFingerState;
boolean newFingerState;
boolean fingerIsPressed = false;
boolean doneAlready = false;
boolean photoCaptured = false;
boolean photoDoneAlready = false;
boolean getPhoto = false;
boolean writeFingerprint = false;
boolean textOpAcending;
boolean photoSort = false;
boolean photoSaved = false;

int printByte1;
int printByte2;
int printByte3;
int printByte4;
int printByte5;

SyphonServer server;
PGraphics canvas;

void setup() {
  size(600, 600, P2D);
  canvas = createGraphics(600, 600, P2D);
  background(0);

  pixelmix = createFont("pixelmix.ttf", 12); //font
  lastTime = millis(); //timer variable used for delay
  waitCount = millis(); //timer variable used for delay
  println(Serial.list());
  serial_port = new Serial(this, Serial.list()[2], 115200); //2 on imac, 4 on macbook
  output = createWriter("fingerprint.txt"); 
  FpsTxBaudRateHigh();
  
    // Create syhpon server to send frames out.
  server = new SyphonServer(this, "Processing Syphon");
}

void draw() {

  background(0);
  printPhase(); //PRINT THE CURRENT PHASE
  displayUserPrompt(); //SHOW USER INSTRUCTIONS


  //PHASE 1
  if (phase == 1) {
    fingerAsk = true;
    //CHECKING IF THE FINGER IS PRESSED EVERY x TIME
    if ( millis() - lastTime > 600 ) {
      //println( "do things every 5 seconds" );
      FpsTxIsPressFinger();
      lastTime = millis();
    } 
    if (phase != 1) {
      fingerAsk = false;
    }
  }

  //PHASE 2
  if (phase == 2) {
    if (doneAlready == false) {
      FpsTxCapture();
      doneAlready = true;
    }
  }

  if (phase == 3) {
    getPhoto = true;    
    if (photoDoneAlready == false) {
      println("SENDING MESSAGE: get image");
      FpsTxGetImage();
      photoDoneAlready = true;
    }
  }

  if (phase == 4) {
    int photoPart = 52115;
    for (int i = 0; i< 52115; i++) {
      photoPart--;
      photo[i] = photoBufferByte[photoPart];
    }

    img.loadPixels();
    for (int i = 0; i< 52116; i++) {
      img.pixels[i] = color(photo[i] + 128);
    }
    
    img.updatePixels();
    image(img, 0, 0, width, height);
    displayUserPrompt();
    if(photoSaved == false){
      img.save("outputImage.bmp"); //save the photo as image
      
    for (int i = 0; i< 52115; i++) {
      output.println(photo[i]);
    }
    output.flush(); // Writes the remaining data to the file
    output.close(); // Finishes the file
    photoSaved = true;
    }
    
  }
  

  //ERROR (PHASE 99)
  if (phase == 99) {
    errorTime--;
    println(errorTime);
    println(phase);
    if (errorTime == 0) phase = 100;
  }

  //RESET (PHASE 100)
  if (phase == 100) {    
    fingerIsPressed = false;
    doneAlready = false;
    photoCaptured = false;
    errorTime = 100;
    textOp = 0;
    photoDoneAlready = false;

    FpsTxLedOn();
    count = 0;
    delay(1000);
    phase = 1;
  }
  
   //syphon
  server.sendScreen();
}

void displayUserPrompt() { //userinstructions
  textFont(pixelmix);

  //TEXT OPACITY
  if (textOp <= 0) textOpAcending = true;
  if (textOp >= 255) textOpAcending = false;
  if (textOpAcending == true) textOp = textOp + 3; 
  if (textOpAcending == false) textOp = textOp - 2;


  //START PROGRAM PROMT
  if (phase == 0) {
    textAlign(CENTER); 
    fill(255, 255);
    text("Press Spacebar to Run Program", width/2, height/2);
  }

  //PLACE FINGER PROMT
  if (fingerIsPressed == false && phase == 1) {
    textAlign(CENTER); 
    fill(255, textOp);
    text("Scan Finger to Initiate", width/2, height/2);
  }

  //KEEP FINGER PROMT
  if (phase == 3) {
    //background(0);
    textAlign(CENTER); 
    fill(255, 200);
    //fill(255, textOp + 100);
    text("Reading Finger", width/2, height/2 - 20);
    fill(255, 200);
    text("Keep Finger Pressed To the Sensor Until Scan Is Complete", width/2, height/2);
    //if(photoCount > 0) {
    // if(printByte1 != rxByte){
    //   text(rxByte, width/2 - 60, height/2 + 20);
    //   text(printByte1, width/2 - 30, height/2 + 20);
    //   printByte1 = rxByte;
    //   if(printByte2 != printByte1){
    //     text(printByte2, width/2, height/2 + 20);
    //     printByte2 = printByte1;
    //   }
    //   if(printByte3 != printByte2){
    //     text(printByte3, width/2 + 30, height/2 + 20);
    //     printByte3 = printByte2;
    //   }
    //   if(printByte4 != printByte3){
    //     text(printByte4, width/2 + 60, height/2 + 20);
    //     printByte4 = printByte3;
    //   }
    // }
    //}
  }

  //KEEP FINGER PROMT
  if (phase == 4 && photoCaptured == true) {
    textAlign(CENTER); 
    fill(255, 255);
    text("Fingerprint Captured!", width/2, height/2 - 20);
    fill(255, textOp + 100);
    text("Please Wait", width/2, height/2);
  }

  //ERROR
  if (phase == 99) {
    textAlign(CENTER); 
    fill(random(256), random(256), random(256), 255 + 100);
    text("ERROR PLEASE TRY AGAIN", width/2, height/2);
  }
}

//PRINT THE CURRENT PHASE
void printPhase() {
  int newPhase = phase;
  if (newPhase != oldPhase) {
    println("Entering Phase " + phase);
    oldPhase = newPhase;
  }
}

void processMessage() {
  println(inBuffer);

  if (fingerAsk == true) { //ARE WE ASKING ABOUT THE FINGER?
    fingerAskState();
  }

  if (phase == 2) {
    capturePhotoState();
  }
}
/////////////////////////////////////////remember to false photocaptured
void capturePhotoState() {
  if (inBuffer[4] == 0 && inBuffer[4] == 0 && phase == 2) {
    answer = true;
    photoCaptured = true;
    println("Photo Captured");
    phase = 3; //END PHASE 2 & START PHASE 3 
    doneAlready = false;
  }
  if (inBuffer[4] != 0 && inBuffer[4] != 0 && phase == 2) {
    answer = false;
    photoCaptured = false;
    println("Error - Photo NOT Captured");
    phase = 99; //END PHASE 2 & START PHASE 3 
    doneAlready = false;
  }
}

void fingerAskState() { //ASKING ABOUT THE FINGER   
  newFingerState = answer;   
  if (inBuffer[4] == 0 && inBuffer[4] == 0 && phase == 1) {
    answer = true;
    fingerIsPressed = true;
    phase = 2; //END PHASE 1 & START PHASE 2

    if (newFingerState != oldFingerState) {
      println("Finger is Pressed");
      oldFingerState = newFingerState;
    }
  } else {
    answer = false;
    fingerIsPressed = false;    
    if (newFingerState != oldFingerState) {
      println("No Finger");
      oldFingerState = newFingerState;
    }
  }
}



///////////////////////////////////////////////////////////////////////////
// serial port event handler
void serialEvent(Serial p)
{

  while (p.available() > 0) {

    if (getPhoto != true) {
      inBuffer[count] = p.readBytes()[0];
      //println(inBuffer[count]);
      count = count + 1;

      //println(count);
      if (count > 11) {
        count = 0;
        //println(count);
        processMessage();
      }
    }

    if (getPhoto == true && phase == 3) {
      rxByte = (byte)serial_port.readChar();
      //println(rxByte);
      hexByte = hex(rxByte);
      //println(hexByte);
      if (hexByte.equals("A5")) photoSort = true;
      if(photoCount == 0) println(hexByte);
      if (photoSort == true && hexByte.equals("00")) writeFingerprint = true;

      if (writeFingerprint == true) {

        //ARRAYS STORING THE PHOTO
        //photoBuffer[photoCount] = (char)p.readChar();
        photoBufferByte[photoCount] = rxByte;
        //println(photoBufferByte[photoCount]);
        println( "photoCount " + photoCount);
        photoCount = photoCount + 1;     

        if (photoCount >= 52116) { 
          
          writeFingerprint = false;
          photoCount = 0;
          phase = 4;
          
        }
      }
    }
  }
}

///////////////////////////////////////////////////////////////////////////



//OTGOING MESSAGES

// switch the fingerprint scanner LED on
void FpsTxLedOn()
{ 
  ledOn = true;
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA)
    0x01, 0x00, // device ID
    0x01, 0x00, 0x00, 0x00, // input parameter
    0x12, 0x00, // command code
    0x13, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}

// switch the fingerprint scanner LED off
void FpsTxLedOff()
{ 
  ledOn = false;
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x00, 0x00, 0x00, 0x00, // input parameter
    0x12, 0x00, // command code
    0x12, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}


// Prompt is press finger?
void FpsTxIsPressFinger()
{ 
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x01, 0x00, 0x00, 0x00, // input parameter
    0x26, 0x00, // command code
    0x27, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
} 

// Take photo
void FpsTxCapture()
{
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x01, 0x00, 0x00, 0x00, // input parameter
    0x60, 0x00, // command code
    0x61, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}

// delete All
void FpsTxDeleteAll()
{
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x01, 0x00, 0x00, 0x00, // input parameter
    0x41, 0x00, // command code
    0x42, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}

// get photo
void FpsTxGetImage()
{
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x01, 0x00, 0x00, 0x00, // input parameter
    0x62, 0x00, // command code
    0x63, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}

// get photo
void FpsTxGetRawImage()
{
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x01, 0x00, 0x00, 0x00, // input parameter
    0x63, 0x00, // command code
    0x64, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}

// change baud rate to 11520
void FpsTxBaudRateHigh()
{
  byte[] tx_cmd = { 0x55, -86, // packet header (-86 == 0xAA) 
    0x01, 0x00, // device ID
    0x00, -62, 0x01, 0x00, // input parameter
    0x04, 0x00, // command code
    -57, 0x01 };            // checksum

  for (int i = 0; i < 12; i++) {
    serial_port.write(tx_cmd[i]);
  }
}


void keyPressed() {
  //KEYS FOR CONTROLLING THE STATES
  if (key == '0') {     
    phase = 0;
    FpsTxLedOff();
  }
  if (key == '1' || key == ' ') {     
    FpsTxLedOn();
    delay(1000);
    textOp = 0;
    phase = 1;
  }
  if (key == '2') {     
    phase = 2;
  }
  if (key == '3') {     
    phase = 3;
  }
  if (key == '4') {     
    phase = 4;
  }
  if (key == '9') {     
    phase = 99;
  }

  if (key == 'q' || key == 'Q') {     
    phase = 100;
  }
  //KEYS FOR CONTROLLING THE SENSOR 

  //MIGHT TRIGGER UNDESIRED CHAINS OF EVENTS IF TRIGGERED IN CERTAIN PHASES
  if (key == 'o' || key == 'O') {
    println("SENDING MESSAGE: led ON");
    FpsTxLedOn();
  }
  if (key == 'p' || key == 'P') {
    println("SENDING MESSAGE: led OFF");
    FpsTxLedOff();
  }  

  if (key == 'f' || key == 'F') {
    FpsTxIsPressFinger();
  }   
  if (key == 'b' || key == 'B') {
    FpsTxBaudRateHigh();
  }   
  if (key == 'c' || key == 'C') {
    println("SENDING MESSAGE: capture fingerprint");
    FpsTxCapture();
  }   
  if (key == 'd' || key == 'D') {
    FpsTxDeleteAll();
    println("SENDING MESSAGE: delete all");
  }   
  if (key == 'g' || key == 'G') {
    FpsTxGetImage();
    println("SENDING MESSAGE: get image");
  } 
  if (key == 'r' || key == 'R') {
    FpsTxGetRawImage();
    println("SENDING MESSAGE: get raw image");
  }
}