

//write data to a text file
class OutputFile_rawtxt {
  PrintWriter _output;
  String _fname;
  
  OutputFile_rawtxt(String fileName) {
    _fname = fileName;
    
    //add year month day to the file name
    _fname = _fname + year() + "-";
    if (month() < 10) _fname=_fname+"0";
    _fname = _fname + month() + "-";
    if (day() < 10) _fname = _fname + "0";
    _fname = _fname + day(); 
    
    //add hour minute sec to the file name
    _fname = _fname + "_";
    if (hour() < 10) _fname = _fname + "0";
    _fname = _fname + hour() + "-";
    if (minute() < 10) _fname = _fname + "0";
    _fname = _fname + minute() + "-";
    if (second() < 10) _fname = _fname + "0";
    _fname = _fname + second();
   
    //add the extension
    _fname = _fname + ".txt";
  }
  
  public void writeRawText (double fs_Hz) {
    _output = createWriter(_fname);
    _output.println("%OpenBCI Raw EEG Data");
    _output.println("%");
    _output.println("%Sample Rate = " + fs_Hz + " Hz");
    _output.println("%First Column = SampleIndex");
    _output.println("%Other Columns = EEG data in microvolts");
    _output.flush();
    _output.close();
  }
  
  public void writeFFTData(double bandWidth, double fftVals[][]) {
    // [Freq] [Channel]
    String fftLine = "";
    int freqeuncyIt = 0;
    for(double[] channels : fftVals){
           fftLine += ("(" + (freqeuncyIt * 1/bandWidth) + "),");
      for(double channelFreqVal : channels){
        fftLine += (channelFreqVal + ",");
      }
      fftLine +=  "\n";
      freqeuncyIt++; 
    }
    
    _output = createWriter(_fname);
    _output.println(fftLine);
    _output.flush();
    _output.close();

  }

  public void writeRawData_txt(float[][] yLittleBuff_uV,int indexOfLastValue) {
    int nchan = yLittleBuff_uV.length;
    int nsamp = yLittleBuff_uV[0].length;
  
    //println("writeRawData: nchan, nsamp = " + nchan + " " + nsamp);
  
    _output = createWriter(_fname);
    for (int i=0; i < nsamp; i++) {
      _output.print(Integer.toString(indexOfLastValue - nsamp + i));
      
       for (int Ichan = 0; Ichan < nchan; Ichan++) {
         _output.print(", ");
         //output.print(Float.toString(yLittleBuff_uV[Ichan][i]));
         _output.print(String.format("%.2f",yLittleBuff_uV[Ichan][i]));
       }
    
      _output.println();
    }
    _output.flush();
    _output.close();
  }
};

