class OpenBCIGlobals {
  
  //Serial communications constants
  final String OPEN_BCI_PORT_NAME = "/dev/tty.usbmodem1431";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/
  
  //TESTING TRIGGER
  final boolean USE_SYNTHETIC_DATA = false; //flip this to false when using OpenBCI
  
  //Open BCI BOARD SETTINGS
  final int OPEN_BCI_BAUD_RATE = 115200; //baud rate from the Arduino
  final int NUM_OPEN_BCI_CHANNELS = 8; //normal OpenBCI has 8 channels
  //use this for when daisy-chaining two OpenBCI boards
  //int OPEN_BCI_BAUD_RATE = 2*115200; //baud rate from the Arduino
  //int NUM_OPEN_BCI_CHANNELS = 16; //daisy chain has 16 channels
  
  //DATA CONSTANTS
  final float FS_HERTZ = 250f;
  final int SIZE_DATA_BACK_BUFFER = (int)FS_HERTZ;
  final float SCALE_FACTOR_U_VOLTS_PER_COUNT = (4.5f / 24.0f / pow(2, 24)) * 1000000.f * 2.0f; //factor of 2 added 2013-11-10 to match empirical tests in my office on Friday
  final int NUMBER_OF_POINTS_PER_UPDATE = 30;
  
  //fft constants
  final int FFT_RESOLUTION = 256; //set resolution of the FFT.  Use N=256 for normal, N=512 for MU waves
  final float FFT_SMOOTHING_FACTOR = 0.75f; //use value between [0 and 1].  Bigger is more smoothing.  Use 0.9 for MU waves, 0.75 for Alpha, 0.0 for no smoothing
  
  //plotting constants
  final float VERTICAL_SCALE = 100.0f;
  final float DISPLAY_TIME_IN_SECONDS = 5f;
  final float DATA_BUFFER_LENGTH_SECONDS = DISPLAY_TIME_IN_SECONDS+2f;
};

