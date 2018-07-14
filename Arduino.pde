/*
2017-10-25
 Template code obtained to get started with Processing and minim
 
 source: http://www.instructables.com/id/How-to-Make-LEDs-Flash-to-Music-with-an-Arduino/
*/

import processing.serial.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import cc.arduino.*;

Minim minim;
AudioPlayer song;
BeatDetect beat;
BeatListener bl;
Arduino arduino;
FFT fft;

int ledPin =  12;    // LED connected to digital pin 12
int ledPin2 =  8;    // LED connected to digital pin 1
int ledPin3 =  2;    // LED connected to digital pin 0

int outputPins[] = {0,0,0,0,0,0};

int CUBE_D = 6;

//drawing parameters
int CUBE_SIZE = 30;
int CUBE_SPACE = 30;

//store on-off state of each LED
boolean cubeState[][][], prevCubeState[][][];

//offset-delay for animations
boolean columnOn[];
boolean faceOn[];

//store frame of pattern animation
int frameCounter[];

//store frame of edge animation
int edgeCounter = 0;
boolean edgeOn;

//amplitude threshold for detecting a beat
float AMP_THRESH = 6;

void setup() {
  fullScreen(P3D);

  minim = new Minim(this);
  arduino = new Arduino(this, Arduino.list()[0], 57600);

  //song = minim.loadFile("Angels.mp3", 2048);
  //song.play(34*1000+500);

  //song = minim.loadFile("Prancing Dad.mp3", 2048);
  //song.play(((3*60)+27)*1000);

  song = minim.loadFile("Dragon Rider.mp3", 2048);
  
  //song = minim.loadFile("Hope and Legacy.mp3", 2048);
  
  //song = minim.loadFile("Star Sky.mp3", 2048);
  
  fft = new FFT(song.bufferSize(), song.sampleRate());
  fft.logAverages(CUBE_D, CUBE_D*CUBE_D);
  
  song.play();

  beat = new BeatDetect(song.bufferSize(), song.sampleRate());

  beat.setSensitivity(35);  

  bl = new BeatListener(beat, song);  

  //arduino.pinMode(ledPin, Arduino.OUTPUT);    
  //arduino.pinMode(ledPin2, Arduino.OUTPUT);  
  //arduino.pinMode(ledPin3, Arduino.OUTPUT);
  
  cubeState = new boolean[CUBE_D][CUBE_D][CUBE_D];
  prevCubeState = new boolean[CUBE_D][CUBE_D][CUBE_D];
  columnOn = new boolean [CUBE_D];
  faceOn = new boolean [CUBE_D];
  
  frameCounter = new int [6];
  
  for(int i = 0; i < 6; i++) {
    arduino.pinMode(outputPins[i], Arduino.OUTPUT);
  }
}

void assignSide(int i, int j, int side, boolean state) {
  if (side == 0) {
    cubeState[0][i][j] = state;
    return;
  }
  else if (side == 1) {
    cubeState[i][0][j] = state;
  }
  else if (side == 2) {
    cubeState[i][j][0] = state;
  }
  else if (side == 3) {
    cubeState[CUBE_D-1][i][j] = state;
  }
  else if (side == 4) {
    cubeState[i][CUBE_D-1][j] = state;
  }
  else if (side == 5) {
    cubeState[i][j][CUBE_D-1] = state;
  }
}

void processBandsPatterns(int side, int pattern) {
  fft.forward(song.mix);
  
  if (beat.isKick()) {
    if (faceOn[side] == true) {
      for(int i = 0; i < CUBE_D-2; i++) {
        for(int j = 0; j < CUBE_D-2; j++) {
          boolean sideState = patterns[pattern][frameCounter[side]][i][j] == 0 ? false : true;
          assignSide(i+1, j+1, side, sideState);
        }
      }
      frameCounter[side] = (frameCounter[side]+1) % 12;
    }
    faceOn[side] = false;
  }
  else {
    faceOn[side] = true;
    
    for(int i = 0; i < CUBE_D; i++) {
      for(int j = 0; j < CUBE_D; j++) {
          assignSide(i, j, side, false);
      }
    }
  }
}

void processWithPatterns() {
  //why are there only 26 wtf
  fft.forward(song.mix);
  
  int NUM_BANDS = 26;
  
  //Pattern: slice-wise, amplitude-based switch for inner 4x4
  //for(int i = 1; i < CUBE_D-1; i++) {
  //  if (beat.isRange(i*NUM_BANDS/CUBE_D, ((i+1)*NUM_BANDS/CUBE_D)-1, NUM_BANDS/(4*CUBE_D))) {
  //      if (columnOn[i] == true) {
  //        for(int j = 1; j < CUBE_D-1; j++) {
  //            for(int k = 1; k < CUBE_D-1; k++) {
  //              if (fft.getBand((i*(CUBE_D-2)*(CUBE_D-2))+(j*(CUBE_D-2))+k) >= AMP_THRESH) {
  //                cubeState[i][j][k] = true;
  //              }
  //            }
  //        }
  //      }
  //    columnOn[i] = false;
  //  }
  //  else {
  //    columnOn[i] = true;
      
  //    for(int j = 1; j < (CUBE_D-1); j++) {
  //      for(int k = 1; k < (CUBE_D-1); k++) {
  //        cubeState[i][j][k] = false;
  //      }
  //    }
  //  }
  //}
  
  //Pattern: individually-based amplitude-based switch for inner 4x4
  for(int i = 1; i < CUBE_D-1; i++) {
    for(int j = 1; j < CUBE_D-1; j++) {
      for(int k = 1; k < CUBE_D-1; k++) {
        if (fft.getBand((i*CUBE_D*CUBE_D)+(j*CUBE_D)+k) >= AMP_THRESH) {
          if (prevCubeState[i][j][k] == true) {
            cubeState[i][j][k] = true;
            prevCubeState[i][j][k] = false;
          }
        }
        else {
          prevCubeState[i][j][k] = true;
          cubeState[i][j][k] = false;
        }
      }
    }
  }
  
  //Pattern: draw patterns on each face of cube
  for(int s = 0; s < 6; s++) {
    //if (beat.isKick()) {
    if (beat.isRange(s*NUM_BANDS/CUBE_D, ((s+1)*NUM_BANDS/CUBE_D)-1, NUM_BANDS/(4*CUBE_D))) {
      if (faceOn[s] == true) {
        for(int i = 0; i < CUBE_D-2; i++) {
          for(int j = 0; j < CUBE_D-2; j++) {
            boolean sideState = patterns[s][frameCounter[s]][i][j] == 0 ? false : true;
            assignSide(i+1, j+1, s, sideState);
          }
        }
        frameCounter[s] = (frameCounter[s]+1) % 12;
      }
      faceOn[s] = false;
    }
    else {
      faceOn[s] = true;
      
      for(int i = 0; i < CUBE_D-2; i++) {
        for(int j = 0; j < CUBE_D-2; j++) {
            assignSide(i+1, j+1, s, false);
        }
      }
    }
  }
  
  //Pattern: Run lights along edges of cube
  if (beat.isKick()) {
    if (edgeOn == true) {
      for(int i = 0; i <= edgeCounter; i++) {
        if (i < 6) {
          cubeState[i][0][0] = true;
          cubeState[0][i][0] = true;
          cubeState[0][0][i] = true;
          
          if (i < 3) {
            cubeState[CUBE_D-1][0][i+3] = false;
            cubeState[CUBE_D-1][i+3][0] = false;
            cubeState[0][CUBE_D-1][i+3] = false;
            cubeState[i+3][CUBE_D-1][0] = false;
            cubeState[0][i+3][CUBE_D-1] = false;
            cubeState[i+3][0][CUBE_D-1] = false;
          }
          else {
            cubeState[i-3][CUBE_D-1][CUBE_D-1] = false;
            cubeState[CUBE_D-1][i-3][CUBE_D-1] = false;
            cubeState[CUBE_D-1][CUBE_D-1][i-3] = false;
          }
        }
        else if (i < 12) {
          cubeState[CUBE_D-1][0][i-6] = true;
          cubeState[CUBE_D-1][i-6][0] = true;
          cubeState[0][CUBE_D-1][i-6] = true;
          cubeState[i-6][CUBE_D-1][0] = true;
          cubeState[0][i-6][CUBE_D-1] = true;
          cubeState[i-6][0][CUBE_D-1] = true;
          
          if (i < 9) {
            cubeState[i-6+3][CUBE_D-1][CUBE_D-1] = false;
            cubeState[CUBE_D-1][i-6+3][CUBE_D-1] = false;
            cubeState[CUBE_D-1][CUBE_D-1][i-6+3] = false;
          }
          else {
            cubeState[i-6-3][0][0] = false;
            cubeState[0][i-6-3][0] = false;
            cubeState[0][0][i-6-3] = false;
          }
        }
        else {
          cubeState[i-12][CUBE_D-1][CUBE_D-1] = true;
          cubeState[CUBE_D-1][i-12][CUBE_D-1] = true;
          cubeState[CUBE_D-1][CUBE_D-1][i-12] = true;
          
          if (i < 15) {
            cubeState[i-12+3][0][0] = false;
            cubeState[0][i-12+3][0] = false;
            cubeState[0][0][i-12+3] = false;
          }
          else {
            cubeState[CUBE_D-1][0][i-12-3] = false;
            cubeState[CUBE_D-1][i-12-3][0] = false;
            cubeState[0][CUBE_D-1][i-12-3] = false;
            cubeState[i-12-3][CUBE_D-1][0] = false;
            cubeState[0][i-12-3][CUBE_D-1] = false;
            cubeState[i-12-3][0][CUBE_D-1] = false;
          }
          
        }
      }
      edgeCounter = (edgeCounter+1)%18;
      edgeOn = false;
    }
    else {
      edgeOn = true; 
    }
  }
}

//void outputToArduino() {
//  for(int i = 0; i < CUBE_D; i++) {
//    for(int j = 0; j < CUBE_D; j++) {
//      for(int k = 0; k < CUBE_D; k++) {
//        arduino.digitalWrite(outputPins[k], cubeState[i][j][k] ? Arduino.HIGH : Arduino.LOW);  
//      }
//      arduino.digitalWrite(/*CLOCK*/, Arduino.HIGH);
//      arduino.digitalWrite(/*CLOCK*/, Arduino.LOW);
//    }
//    arduino.digitalWrite(/*LATCH*/, Arduino.HIGH);
//    arduino.digitalWrite(/*LATCH*/, Arduino.LOW);
    
//    /*transistor stuff here*/
//  }
//}

float xmag, ymag = 0;
float newXmag, newYmag = 0;

void draw() {
  background(0);
  
  translate(width/2, height/2, -30); 
  newXmag = mouseX/float(width) * TWO_PI;
  newYmag = mouseY/float(height) * TWO_PI;
  
  float diff = xmag-newXmag;
  if (abs(diff) >  0.01) { 
    xmag -= diff/4.0; 
  }
  
  diff = ymag-newYmag;
  if (abs(diff) >  0.01) { 
    ymag -= diff/4.0; 
  }
  
  rotateX(-ymag); 
  rotateY(-xmag);
  
  processWithPatterns();
  
  for (int i = 0; i < CUBE_D; i++) {
    for (int j = 0; j < CUBE_D; j++) {
      for (int k = 0; k < CUBE_D; k++) {
        
        if (cubeState[i][j][k] == true) {
          fill((i+1)*(255/CUBE_D), (j+1)*(255/CUBE_D), (k+1)*(255/CUBE_D));
        }
        else {
          fill(50);
        }
        int xShift = ((i-(CUBE_D/2))*(CUBE_SIZE+CUBE_SPACE));
        int yShift = ((j-(CUBE_D/2))*(CUBE_SIZE+CUBE_SPACE));
        int zShift = ((k-(CUBE_D/2))*(CUBE_SIZE+CUBE_SPACE));
        translate(xShift, yShift, zShift);
        box(CUBE_SIZE);
        translate(-xShift, -yShift, -zShift);
      }
    }
  }
}

void stop() {
  // always close Minim audio classes when you are finished with them
  cubeState = null;
  prevCubeState = null;
  columnOn = null;
  faceOn = null;
  frameCounter = null;
  
  outputPins = null;
  
  song.close();
  // always stop Minim before exiting
  minim.stop();
  // this closes the sketch
  super.stop();
}