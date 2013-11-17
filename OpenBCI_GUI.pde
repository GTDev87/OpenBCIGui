
///////////////////////////////////////////////
//
// GUI for controlling the ADS1299-based OpenBCI Shield
//
// Created: Chip Audette, Oct-Nov 2013
//
// Requires gwoptics graphing library for processing.  Built on V0.5.0
// http://www.gwoptics.org/processing/gwoptics_p5lib/
//
// No warranty.  Use at your own risk.  Use for whatever you'd like.
// 
///////////////////////////////////////////////


import processing.serial.*;
import ddf.minim.analysis.*; //for FFT
import java.util.*; //for Array.copyOfRange()
import java.lang.Math; //for exp, log, sqrt...they seem better than Processing's built-in
//import processing.core.PApplet;

//CONSTANTS
//Serial communications constants
final String OPEN_BCI_PORT_NAME = "/dev/tty.usbmodem1431";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/

//TESTING TRIGGER
final boolean USE_SYNTHETIC_DATA = true; //flip this to false when using OpenBCI

//Open BCI BOARD SETTINGS
final int OPEN_BCI_BAUD_RATE = 115200; //baud rate from the Arduino
final int NUM_OPEN_BCI_CHANNELS = 8; //normal OpenBCI has 8 channels
//use this for when daisy-chaining two OpenBCI boards
//int OPEN_BCI_BAUD_RATE = 2*115200; //baud rate from the Arduino
//int NUM_OPEN_BCI_CHANNELS = 16; //daisy chain has 16 channels

//DATA CONSTANTS
final float FS_HERTZ = 250f;
final int nDataBackBuff = (int)FS_HERTZ;
final float SCALE_FACTOR_U_VOLTS_PER_COUNT = (4.5f / 24.0f / pow(2, 24)) * 1000000.f * 2.0f; //factor of 2 added 2013-11-10 to match empirical tests in my office on Friday
final int NUMBER_OF_POINTS_PER_UPDATE = 30;

//fft constants
final int Nfft = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
final float fft_smooth_fac = 0.75f; //use value between [0 and 1].  Bigger is more smoothing.  Use 0.9 for MU waves, 0.75 for Alpha, 0.0 for no smoothing

//plotting constants
final float vertScale_uV = 100.0f;
final float displayTime_sec = 5f;
final float dataBuff_len_sec = displayTime_sec+2f;

//END OF CONSTANTS


openBCI_ADS1299 _openBCI;

float yLittleBuff[] = new float[NUMBER_OF_POINTS_PER_UPDATE];

//filter constants
float yLittleBuff_uV[][] = new float[NUM_OPEN_BCI_CHANNELS][NUMBER_OF_POINTS_PER_UPDATE];
float filtState[] = new float[NUM_OPEN_BCI_CHANNELS];

float dataBuffX[];
float dataBuffY_uV[][]; //2D array to handle multiple data channels, each row is a new channel so that dataBuffY[3][] is channel 4
float dataBuffY_filtY_uV[][];
float data_std_uV[];

//define filter...Matlab....butter(2,[1 50]/(250/2));  %bandpass filter
double[] b = new double[]{ 2.001387256580675e-001, 0.0f, -4.002774513161350e-001, 0.0f, 2.001387256580675e-001 };
double[] a = new double[]{ 1.0f, -2.355934631131582e+000, 1.941257088655214e+000, -7.847063755334187e-001, 1.999076052968340e-001 };
filterConstants filtCoeff_bp =  new filterConstants(b,a,"Bandpass 1-50Hz");
double[] b2 = new double[]{ 9.650809863447347e-001, -2.424683201757643e-001, 1.945391494128786e+000, -2.424683201757643e-001, 9.650809863447347e-001};
double[] a2 = new double[]{    1.000000000000000e+000,   -2.467782611297853e-001,    1.944171784691352e+000,   -2.381583792217435e-001,    9.313816821269039e-001}; 
filterConstants filtCoeff_notch =  new filterConstants(b2,a2,"Notch 1-50Hz");




FFT fftBuff[] = new FFT[NUM_OPEN_BCI_CHANNELS];   //from the minim library


gui_headFftMontage gui;





boolean isRunning=false;
int openBCI_byteCount = 0;
int inByte = -1;    // Incoming serial data

//file writing variables
//PrintWriter fileoutput;

OutputFile_rawtxt fileRawOutput = new OutputFile_rawtxt("rawdata/openBCI_raw_");
OutputFile_rawtxt fileFftOutput = new OutputFile_rawtxt("fftdata/openBCI_fft_");
String output_fname;

//openBCI data packet

dataPacket_ADS1299 dataPacketBuff[] = new dataPacket_ADS1299[nDataBackBuff]; //allocate the array, but doesn't call constructor.  Still need to call the constructor!
int curDataPacketInd = -1;
int lastReadDataPacketInd = -1;

void appendAndShift(float[] data, float[] newData) {
  int nshift = newData.length;
  int end = data.length-nshift;
  for (int i=0; i < end; i++) {
    data[i]=data[i+nshift];  //shift data points down by 1
  }
  for (int i=0; i<nshift;i++) {
    data[end+i] = newData[i];  //append new data
  }
}


void prepareData(float[] dataBuffX, float[][] dataBuffY_uV, float hertz) {
  //initialize the x and y data
  int xoffset = dataBuffX.length - 1;
  for (int i=0; i < dataBuffX.length; i++) {
    dataBuffX[i] = ((float)(i-xoffset)) / hertz; //x data goes from minus time up to zero
    for (int Ichan = 0; Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) { 
      dataBuffY_uV[Ichan][i] = 0f;  //make the y data all zeros
    }
  }
}

void initializeFFTObjects(FFT[] fftBuff, float[][] dataBuffY_uV, int N, float FS_HERTZ) {

  float[] fooData;
  for (int Ichan=0; Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) {
    //make the FFT objects...Following "SoundSpectrum" example that came with the Minim library
    //fftBuff[Ichan] = new FFT(Nfft, FS_HERTZ);  //I can't have this here...it must be in setup
    fftBuff[Ichan].window(FFT.HAMMING);

    //do the FFT on the initial data
    fooData = dataBuffY_uV[Ichan];
    fooData = Arrays.copyOfRange(fooData, fooData.length-Nfft, fooData.length); 
    fftBuff[Ichan].forward(fooData); //compute FFT on this channel of data
  }
}


void setup() {

  println("Starting setup...");

  //open window
  int win_x = 1200;  
  int win_y = 768;  //desktop PC
  size(win_x, win_y, P2D);
  //if (frame != null) frame.setResizable(true);  //make window resizable

  //prepare data variables
  dataBuffX = new float[(int)(dataBuff_len_sec * FS_HERTZ)];
  dataBuffY_uV = new float[NUM_OPEN_BCI_CHANNELS][dataBuffX.length];
  dataBuffY_filtY_uV = new float[NUM_OPEN_BCI_CHANNELS][dataBuffX.length];
  data_std_uV = new float[NUM_OPEN_BCI_CHANNELS];
  for (int i=0; i<nDataBackBuff;i++) { 
    dataPacketBuff[i] = new dataPacket_ADS1299(NUM_OPEN_BCI_CHANNELS);
  }


  //initialize the data
  prepareData(dataBuffX, dataBuffY_uV, FS_HERTZ);

  //initialize the FFT objects
  for (int Ichan=0; Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) { 
    fftBuff[Ichan] = new FFT(Nfft, FS_HERTZ);
  };  //make the FFT objects
  initializeFFTObjects(fftBuff, dataBuffY_uV, Nfft, FS_HERTZ);

  //initilize the GUI
  gui = new gui_headFftMontage(this, win_x, win_y, NUM_OPEN_BCI_CHANNELS, displayTime_sec,vertScale_uV);

  //associate the data to the GUI traces
  gui.initDataTraces(dataBuffX, dataBuffY_filtY_uV, fftBuff, data_std_uV);

  //open the data filte for writing
  fileRawOutput.writeRawText(FS_HERTZ);
  output_fname = fileRawOutput._fname;
  println("openBCI: opened output file: " + output_fname);

  // Open the serial port to the Arduino that has the OpenBCI
  if (!USE_SYNTHETIC_DATA) {
    if (true) {
      println(Serial.list());
      //OPEN_BCI_PORT_NAME = Serial.list()[0]; //change this for your computer!
    }
    println("Opening Serial " + OPEN_BCI_PORT_NAME);
    _openBCI = new openBCI_ADS1299(this, OPEN_BCI_PORT_NAME, OPEN_BCI_BAUD_RATE, NUM_OPEN_BCI_CHANNELS); //this also starts the data transfer after XX seconds
  }

  //start
  isRunning=true;

  println("setup: Setup complete...");
}

int pointCounter = 0;
//boolean newData = true;
int prevBytes = 0; 
int prevMillis=millis();
int byteRate_perSec = 0;
void draw() {
  //newData = false;
  if (isRunning) {
    if (USE_SYNTHETIC_DATA) {  //use synthetic data (for GUI debugging) or use real data from the Serial stream
      lastReadDataPacketInd = 0;
      for (int i = 0; i < NUMBER_OF_POINTS_PER_UPDATE; i++) {
        //synthesize data
        dataPacketBuff[lastReadDataPacketInd].sampleIndex++;
        synthesizeData(NUM_OPEN_BCI_CHANNELS, FS_HERTZ, SCALE_FACTOR_U_VOLTS_PER_COUNT, dataPacketBuff[lastReadDataPacketInd]);

        //gather the data into the "little buffer"
        for (int Ichan=0; Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) {
          //scale the data into engineering units..."microvolts"
          yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan]* SCALE_FACTOR_U_VOLTS_PER_COUNT;
        }
        pointCounter++;
      }
    } else {
      _openBCI.updateState();

      //is data waiting in the buffer from the serial port?
      if (curDataPacketInd != lastReadDataPacketInd) {
        //gather the data into the "little buffer"
        while ( (curDataPacketInd != lastReadDataPacketInd) && (pointCounter < NUMBER_OF_POINTS_PER_UPDATE)) {
          lastReadDataPacketInd = (lastReadDataPacketInd+1) % dataPacketBuff.length;
          for (int Ichan=0; Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) {
            //scale the data into engineering units..."microvolts"
            yLittleBuff_uV[Ichan][pointCounter] = dataPacketBuff[lastReadDataPacketInd].values[Ichan]* SCALE_FACTOR_U_VOLTS_PER_COUNT;
          } 
          pointCounter++;
        }
      }
    }

    //has enough data arrived to process it and update the GUI?
    //println("pointCounter " + pointCounter + ", NUMBER_OF_POINTS_PER_UPDATE " + NUMBER_OF_POINTS_PER_UPDATE);
    if (pointCounter >= NUMBER_OF_POINTS_PER_UPDATE) {
      pointCounter = 0;  //reset for next time
      byteRate_perSec = (int)(1000.f * ((float)(openBCI_byteCount - prevBytes)) / ((float)(millis() - prevMillis)));
      prevBytes = openBCI_byteCount; 
      prevMillis=millis();
      float foo_val;
      float prevFFTdata[] = new float[fftBuff[0].specSize()];
      
      double fooVals[][] = new double[fftBuff[0].specSize()][NUM_OPEN_BCI_CHANNELS];
      
      double bandWidth = fftBuff[0].getBandWidth();
      
      for (int Ichan=0;Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) {
        
        //append data to larger buffer
        appendAndShift(dataBuffY_uV[Ichan], yLittleBuff_uV[Ichan]);

        //process the time domain data
        dataBuffY_filtY_uV[Ichan] = dataBuffY_uV[Ichan].clone();
        filterIIR(filtCoeff_notch.b, filtCoeff_notch.a, dataBuffY_filtY_uV[Ichan]); //notch
        filterIIR(filtCoeff_bp.b, filtCoeff_bp.a, dataBuffY_filtY_uV[Ichan]); //bandpass

        //update the FFT stuff
        for (int I=0; I < fftBuff[Ichan].specSize(); I++) prevFFTdata[I] = fftBuff[Ichan].getBand(I); //copy the old spectrum values
        float[] fooData_raw = dataBuffY_uV[Ichan];  //use the raw data
        fooData_raw = Arrays.copyOfRange(fooData_raw, fooData_raw.length-Nfft, fooData_raw.length);   //just grab the most recent block of data
        fftBuff[Ichan].forward(fooData_raw); //compute FFT on this channel of data
        
        //average the FFT with previous FFT data
        double min_val = 0.01d;
        double foo;
        
        for (int I=0; I < fftBuff[Ichan].specSize(); I++) {
          
          if (prevFFTdata[I] < min_val) prevFFTdata[I] = (float)min_val; //make sure we're not too small for the log calls
          foo = fftBuff[Ichan].getBand(I); if (foo < min_val) foo = min_val; //make sure this value isn't too small
          fooVals[I][Ichan] = foo;
          foo =   (1.0d-fft_smooth_fac) * java.lang.Math.log(java.lang.Math.pow(foo,2));
          foo += fft_smooth_fac * java.lang.Math.log(java.lang.Math.pow((double)prevFFTdata[I],2)); 
          foo_val = (float)java.lang.Math.sqrt(java.lang.Math.exp(foo)); //average in dB space
          fftBuff[Ichan].setBand(I,foo_val);
          
        }
    
        //compute the stddev for the head plot
        float[] fooData_filt = dataBuffY_filtY_uV[Ichan];  //use the filtered data
        fooData_filt = Arrays.copyOfRange(fooData_filt, fooData_filt.length-Nfft, fooData_filt.length);   //just grab the most recent block of data
        data_std_uV[Ichan]=std(fooData_filt);
      }
      
      fileFftOutput.writeFFTData(bandWidth, fooVals);

      //tell the GUI that it has received new data via dumping new data into arrays that the GUI has pointers to
      gui.update();
      
      //write data to file
      if (output_fname != null) fileRawOutput.writeRawData_txt(yLittleBuff_uV,dataPacketBuff[lastReadDataPacketInd].sampleIndex);
    } 
    else {
      //not enough data has arrived yet.  do nothing more
    }
  }

  //redraw the screen...not every time, get paced by when data is being plotted
  background(0);
  gui.draw();
  frame.setTitle(int(frameRate) + " fps, Byte Count = " + openBCI_byteCount + ", bit rate = " + byteRate_perSec*8 + " bps" + ", Writing to " + output_fname);
}

void serialEvent(Serial port) {
  //check to see which serial port it is
  if (port == _openBCI.serial_openBCI) {
    boolean echoBytes = !_openBCI.isStateNormal(); 
    _openBCI.read(echoBytes);
    openBCI_byteCount++;
    if (_openBCI.isNewDataPacketAvailable) {
      curDataPacketInd = (curDataPacketInd+1) % dataPacketBuff.length;
      _openBCI.copyDataPacketTo(dataPacketBuff[curDataPacketInd]);
    }
  } 
  else {
    inByte = port.read();
    print(char(inByte));
  }
}

//interpret a keypress...the key pressed comes in as "key"
void keyPressed() {
  switch (key) {
    case '1':
      deactivateChannel(1-1); 
      break;
    case '2':
      deactivateChannel(2-1); 
      break;
    case '3':
      deactivateChannel(3-1); 
      break;
    case '4':
      deactivateChannel(4-1); 
      break;
    case '5':
      deactivateChannel(5-1); 
      break;
    case '6':
      deactivateChannel(6-1); 
      break;
    case '7':
      deactivateChannel(7-1); 
      break;
    case '8':
      deactivateChannel(8-1); 
      break;
    case 'q':
      activateChannel(1-1); 
      break;
    case 'w':
      activateChannel(2-1); 
      break;
    case 'e':
      activateChannel(3-1); 
      break;
    case 'r':
      activateChannel(4-1); 
      break;
    case 't':
      activateChannel(5-1); 
      break;
    case 'y':
      activateChannel(6-1); 
      break;
    case 'u':
      activateChannel(7-1); 
      break;
    case 'i':
      activateChannel(8-1); 
      break;
    case 's':
      stopButtonWasPressed();
      break;
    case 'm':
     println("'m' was pressed...taking screenshot...");
     saveFrame("OpenBCI-####.jpg");    // take a shot of that!
     break;
    default: 
      println("OpenBCI_GUI: '" + key + "' Pressed...sending to OpenBCI...");
      if (_openBCI != null) _openBCI.serial_openBCI.write(key + "\n"); //send the value as ascii with a newline character
  }
}

//swtich yard if a click is detected
void mousePressed() {

  //was the stopButton pressed?
  if (gui.stopButton.updateIsMouseHere()) { 
    stopButtonWasPressed(); 
    gui.stopButton.setIsActive(true);
  }

  //check the channel buttons
  for (int Ibut = 0; Ibut < gui.chanButtons.length; Ibut++) {
    if (gui.chanButtons[Ibut].updateIsMouseHere()) { 
      toggleChannelState(Ibut);
    }
  }
}

void mouseReleased() {
  //gui.stopButton.updateMouseIsReleased();
  gui.stopButton.setIsActive(false);
}

//execute this function whenver the stop button is pressed
void stopButtonWasPressed() {
  //toggle the data transfer state of the ADS1299...stop it or start it...
  if (isRunning) {
    println("openBCI_GUI: stopButton was pressed...stopping data transfer...");
    if (_openBCI != null) _openBCI.stopDataTransfer();
  } 
  else {
    println("openBCI_GUI: startButton was pressed...starting data transfer...");
    if (_openBCI != null) _openBCI.startDataTransfer(); //use whatever was the previous data transfer mode (TXT vs BINARY)
  }

  isRunning = !isRunning;  //toggle the variable holding the current state of running

  //update the push button with new text based on the current running state
  //gui.stopButton.setActive(isRunning);
  if (isRunning) {
    gui.stopButton.setString(stopButton_pressToStop_txt);
  } 
  else {
    gui.stopButton.setString(stopButton_pressToStart_txt);
  }
}

void synthesizeData(int NUM_OPEN_BCI_CHANNELS, float FS_HERTZ, float SCALE_FACTOR_U_VOLTS_PER_COUNT, dataPacket_ADS1299 curDataPacket) {
  float val_uV;
  for (int Ichan=0; Ichan < NUM_OPEN_BCI_CHANNELS; Ichan++) {
    if (gui.chanButtons[Ichan].isActive()==false) { //an INACTIVE button has not been pressed, which means that the channel itself is ACTIVE
      val_uV = randomGaussian()*sqrt(FS_HERTZ/2.0f); // ensures that it has amplitude of one unit per sqrt(Hz) of signal bandwidth
      //val_uV = random(1)*sqrt(FS_HERTZ/2.0f); // ensures that it has amplitude of one unit per sqrt(Hz) of signal bandwidth
      if (Ichan==0) val_uV*= 10f;  //scale one channel higher
    } 
    else {
      val_uV = 0.0f;
    }
    curDataPacket.values[Ichan] = (int) (0.5f+ val_uV / SCALE_FACTOR_U_VOLTS_PER_COUNT); //convert to counts, the 0.5 is to ensure rounding
  }
}

//toggleChannelState: : Ichan is [0 NUM_OPEN_BCI_CHANNELS-1]
void toggleChannelState(int Ichan) {
  if ((Ichan >= 0) && (Ichan < gui.chanButtons.length)) {
    if (gui.chanButtons[Ichan].isActive()) { //button is pressed, which means the channel was NOT active
      //change to activate
      activateChannel(Ichan);
    } 
    else {  //button is not pressed, which means the channel is active
      //change to activate
      deactivateChannel(Ichan);
    }
  }
}

//activateChannel: Ichan is [0 NUM_OPEN_BCI_CHANNELS-1]
void activateChannel(int Ichan) {
  println("OpenBCI_GUI: activating channel " + (Ichan+1));
  if (_openBCI != null) _openBCI.changeChannelState(Ichan, true); //activate
  gui.chanButtons[Ichan].setIsActive(false); //an active channel is a light-colored NOT-ACTIVE button
}  
void deactivateChannel(int Ichan) {
  println("OpenBCI_GUI: deactivating chnnel " + (Ichan+1));
  if (_openBCI != null) _openBCI.changeChannelState(Ichan, false); //de-activate
  gui.chanButtons[Ichan].setIsActive(true); //a deactivated channel is a dark-colored ACTIVE button
}

