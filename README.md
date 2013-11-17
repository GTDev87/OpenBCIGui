# BCI GUI

## Prerequisites
* Processing - Download Processing 2.0.3 [Node.js](https://processing.org/download/?processing).

### Setup
* Start project in Processing
* Edit - OpenBCI_GUI 
final String OPEN_BCI_PORT_NAME = "/dev/tty.usbmodem1431";   /************** CHANGE THIS TO MATCH THE COM PORT REPORTED ON *YOUR* COMPUTER *****************/ 

### Testing
final boolean USE_SYNTHETIC_DATA = true;

### Data
* Raw data gets sent to /rawdata
* FFT data gets sent to /fftdata
