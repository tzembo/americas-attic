/*

America's Attic

First, launch OpenCV Python script.
Then, launch in Processing IDE.

*/

import processing.net.*; 
import processing.video.*;
import lord_of_galaxy.timing_utils.*;
import processing.sound.*;

PApplet app;
Client c;

// Constants for Flashlight behavior
float MAX_TRACKED_RADIUS = 100;
float MIN_TRACKED_RADIUS = 20;

float MAX_SCREEN_RADIUS = 210;
float MIN_SCREEN_RADIUS = 130;

float MAX_TRACKED_DEPTH = 8;
float MIN_TRACKED_DEPTH = 2;

float MAX_ALPHA = 255;
float MIN_ALPHA = -550;

float MAPPING_PROD = 115;

Stopwatch inactivity;

// Variables for reading point data
String raw;
JSONObject data;
JSONArray coordinates;
JSONArray tuple;
int lf = 10;
float[][] points;
int numPoints = 0;

// Mask variables
PImage mask;
float maskVal;

PImage backgroundImage;
PFont newFont;

int NONE = 0;
int PHOTO = 1;
int VIDEO = 2;

Object[] content;   // array of content objects

// class for storing content information
class Object {
  
  int type;
  int x, y, w, h;
  int textX, textY, textW, textH;
  
  String file;
  PImage photo;
  Movie video;
  
  String info;
  Stopwatch s;
  Stopwatch s_trigger;
  boolean textOn;
  float textAlpha;
  float textStep; 

  // constructor
  Object(int newType, int newX, int newY, int newW, int newH, int newTextX, int newTextY, int newTextW, int newTextH, String newFile, String newInfo) {
    
    // populate from arguments
    type = newType;
    x = newX;
    y = newY;
    w = newW;
    h = newH;
    textX = newTextX;
    textY = newTextY;
    textW = newTextW;
    textH = newTextH;
    file = newFile;
    info = newInfo;
    
    // load media file
    if (type == PHOTO) {
      photo = loadImage(file);
      photo.resize(200, 0);
    } else if (type == VIDEO) {
      video = new Movie(app, file);
      video.loop();
    }
    
    // initialize timing
    s = new Stopwatch(app);
    s_trigger = new Stopwatch(app);
    textStep = 5;
    textAlpha = 0;
    
  }
  
  // render media
  void display() {
    if (type == PHOTO) {
      image(photo, x, y);
    } else if (type == VIDEO) {
      image(video, x, y);
    }
  }
  
  // whether user is in trigger box
  boolean overArea(float[][] pts, int numPts) {
    for (int i = 0; i < numPts; i++) {
      if (pts[i][0] >= x && pts[i][0] <= x+w && 
          pts[i][1] >= y && pts[i][1] <= y+h) {
        return true;
      }
    }
    return false;
  }
    
  void displayText(int maxTime, boolean active) {
    
    if (active) {
      if (s_trigger.isPaused()) {
        s_trigger.start();
      }
      
      if (!textOn && s_trigger.time() > 1500) {
        textOn = true;
        println("HERE!");
        s.start();
      } else {
        s.restart();
      }
    } else {
      s_trigger.reset();
    }
    
    if (s.time() > maxTime) {
      textOn = false;
      s.reset();
    }
    
    if (textOn) {
      textAlpha += textStep;
    } else {
      textAlpha -= textStep;
    }
    
    textAlpha = constrain(textAlpha, 0, 255);
    stroke(0, 0);
    fill(255, textAlpha);
    if (textX != 0) {
      text(info, textX, textY, textW, 200); 
    }
    fill(255, 255);
    stroke(0, 0);
  }
}

void setup() {

  // Initialize sketch
  app = this;
  fullScreen();
  background(0);
  
  // Create font
  newFont = createFont("Georgia", 14);
  textFont(newFont);
  textLeading(22);
  
  rectMode(CENTER);
  text("Loading...", width/2, height/2, 200, 200);
  rectMode(CORNER);
  c = new Client(this, "127.0.0.1", 5005); // Replace with your server’s IP and port
    
  inactivity = new Stopwatch(this);
  inactivity.start();
  
  // Create mask
  mask = createImage(width, height, ALPHA);
  mask.loadPixels();
  for (int i = 0; i < mask.pixels.length; i++) {
    mask.pixels[i] = color(0, 255);
  }
  mask.updatePixels();
  
  JSONObject backgroundData = loadJSONObject("Content1210.json").getJSONObject("background");
  backgroundImage = loadImage(backgroundData.getString("file"));
  backgroundImage.resize(width, 0);
  
  JSONArray contentData = loadJSONObject("Content1210.json").getJSONArray("content");
  content = new Object[contentData.size()];
  for (int i = 0; i < contentData.size(); i++) {
    JSONObject data = contentData.getJSONObject(i);
    content[i] = new Object(data.getInt("type"), data.getInt("x"), data.getInt("y"), data.getInt("w"),
                            data.getInt("h"), data.getInt("textX"), data.getInt("textY"), data.getInt("textW"),
                            data.getInt("textH"), data.getString("file"), data.getString("text"));
  }
  
  points = new float[10][];
  numPoints = 0;
}

void draw() {

  if (c.available() > 0) { 
    while(true) {
      raw = c.readString();
      try {
        data = parseJSONObject(raw);
      }
      catch(RuntimeException e) {
        break;  // break out of while loop
      }
      numPoints = 0;
      coordinates = data.getJSONArray("pts");
      
      // inactivity stopwatch
      if (coordinates.size() == 0) {
        if (inactivity.isPaused()) {
          inactivity.start();
        }
      } else {
        inactivity.reset();
      }
      
      for (int i = 0; i < coordinates.size(); i++) {
        if (i == 10) {
          break;
        }
        tuple = coordinates.getJSONArray(i);
        points[i] = float(tuple.getIntArray());
        points[i][0] = map(points[i][0], 0, 1920, 0, width);
        points[i][1] = map(points[i][1], 0, 1080, 0, height);
        numPoints++;
      }
      break;
    }
  }
  
  // clear sketch
  if (numPoints == 0) {
    
    background(0);
    
    // render inactivity message
    if (inactivity.time() > 4000) {
      rectMode(CENTER);
      text("To begin exploring, use your AIB orb.", width/2, height/2, 200, 200);
      rectMode(CORNER);
    }
  } else {
    
    background(30);
    image(backgroundImage, 0, 0);
    
    // render media
    for (int i = 0; i < content.length; i++) {
      content[i].display();
    }
    
    // apply mask
    updateMask(points, numPoints);
    
    // render text
    for (int i = 0; i < content.length; i++) {
      boolean active = content[i].overArea(points, numPoints);
      content[i].displayText(2000, active);
    }
  }
}

// updates mask based on CV coordinates
void updateMask(float[][] pts, int numPts) {
  mask.loadPixels();
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int loc = x + y*width;
      float sum = 0;
      for (int i = 0; i < numPts; i++) {
        // float camX = map(pts[i][0], 0, 1920, 0, width);
        // float camY = map(pts[i][1], 0, 1080, 0, height);
        float depth = computeDepth(pts[i][2]);
        float radius = computeRadius(depth);
        float brightness = computeBrightness(depth);
        float distance = dist(pts[i][0], pts[i][1], x, y);
        if (distance < radius) {
          maskVal = map(distance, 0, radius, brightness, 255);
          sum += (255 - maskVal);
        }
      }
      mask.pixels[loc] = color(0, 255 - sum);
    }
  } 
  mask.updatePixels();
  image(mask, 0, 0);
}

float computeRadiusSimple(int trackedRadius) {
  return trackedRadius;
}

float computeDepth(float trackedRadius) {
  float depth = MAPPING_PROD / trackedRadius;
  depth = constrain(depth, MIN_TRACKED_DEPTH, MAX_TRACKED_DEPTH);
  return depth;
}

float computeRadius(float depth) {
  float radius = map(depth, MIN_TRACKED_DEPTH, MAX_TRACKED_DEPTH, MIN_SCREEN_RADIUS, MAX_SCREEN_RADIUS);
  return radius;
}

float computeBrightness(float depth) {
  float brightness = map(depth, MIN_TRACKED_DEPTH, MAX_TRACKED_DEPTH, MIN_ALPHA, MAX_ALPHA);
  return brightness;
}
