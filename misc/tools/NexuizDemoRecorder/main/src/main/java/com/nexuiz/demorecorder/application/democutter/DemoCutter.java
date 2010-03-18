package com.nexuiz.demorecorder.application.democutter;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.EOFException;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

public class DemoCutter {

	private static final byte CDTRACK_SEPARATOR = 0x0A;

	private DataInputStream inStream;
	private DataOutputStream outStream;
	private File inFile;
	private File outFile;

	/**
	 * Calls the cutDemo method with reasonable default values for the second and first fast-forward stage.
	 * @param inFile @see other cutDemo method
	 * @param outFile @see other cutDemo method
	 * @param startTime @see other cutDemo method
	 * @param endTime @see other cutDemo method
	 * @param injectAtStart @see other cutDemo method
	 * @param injectBeforeCap @see other cutDemo method
	 * @param injectAfterCap @see other cutDemo method
	 */
	public void cutDemo(File inFile, File outFile, float startTime, float endTime, String injectAtStart, String injectBeforeCap, String injectAfterCap) {
		this.cutDemo(inFile, outFile, startTime, endTime, injectAtStart, injectBeforeCap, injectAfterCap, 100, 10);
	}
	
	/**
	 * Cuts the demo by injecting a 2-phase fast forward command until startTime is reached, then injects the cl_capturevideo 1 command
	 * and once endTime is reached the cl_capturevideo 0 command is injected.
	 * @param inFile the original demo file
	 * @param outFile the new cut demo file
	 * @param startTime when to start capturing (use the gametime in seconds)
	 * @param endTime when to stop capturing
	 * @param injectAtStart a String that will be injected right at the beginning of the demo
	 * 						can be anything that would make sense and can be parsed by DP's console
	 * @param injectBeforeCap a String that will be injected 5 seconds before capturing starts
	 * @param injectAfterCap a String that will be injected shortly after capturing ended
	 * @param ffwSpeedFirstStage fast-forward speed at first stage, when the startTime is still about a minute away (use high values, e.g. 100)
	 * @param ffwSpeedSecondStage fast-forward speed when coming a few seconds close to startTime, use lower values e.g. 5 or 10
	 */
	public void cutDemo(File inFile, File outFile, float startTime, float endTime, String injectAtStart, String injectBeforeCap, String injectAfterCap, int ffwSpeedFirstStage, int ffwSpeedSecondStage) {
		this.inFile = inFile;
		this.outFile = outFile;
		this.prepareStreams();
		this.readCDTrack();
		injectAfterCap = this.checkInjectString(injectAfterCap);
		injectAtStart = this.checkInjectString(injectAtStart);
		injectBeforeCap = this.checkInjectString(injectBeforeCap);

		byte[] data;
		float svctime = -1;
		boolean firstLoop = true;
		String injectBuffer = "";
		int demoStarted = 0;
		boolean endIsReached = false;
		boolean finalInjectionDone = false;
		boolean disconnectIssued = false;
		int svcLoops = 0;
		float firstSvcTime = -1;
		float lastSvcTime = -1;
		
		try {
			while (true) {
				DemoPacket demoPacket = new DemoPacket(this.inStream);
				if (demoPacket.isEndOfFile()) {
					break;
				}
				
				if (demoPacket.isClientToServerPacket()) {
					try {
						this.outStream.write(demoPacket.getOriginalLengthAsByte());
						this.outStream.write(demoPacket.getAngles());
						this.outStream.write(demoPacket.getOriginalData());
					} catch (IOException e) {
						throw new DemoCutterException("Unexpected I/O Exception occurred when writing to the cut demo", e);
					}
					
					continue;
				}

				if (demoPacket.getSvcTime() != -1) {
					svctime = demoPacket.getSvcTime();
				}

				if (svctime != -1) {
					if (firstSvcTime == -1) {
						firstSvcTime = svctime;
					}
					lastSvcTime = svctime;
					
					if (firstLoop) {
						injectBuffer = "\011\n" + injectAtStart + ";slowmo " + ffwSpeedFirstStage + "\n\000";
						firstLoop = false;
					}
					if (demoStarted < 1 && svctime > (startTime - 50)) {
						if (svcLoops == 0) {
							//make sure that for short demos (duration less than 50 sec)
							//the injectAtStart is still honored
							injectBuffer = "\011\n" + injectAtStart + ";slowmo " + ffwSpeedSecondStage + "\n\000";
						} else {
							injectBuffer = "\011\nslowmo " + ffwSpeedSecondStage + "\n\000";
						}
						
						demoStarted = 1;
					}
					if (demoStarted < 2 && svctime > (startTime - 5)) {
						injectBuffer = "\011\nslowmo 1;" + injectBeforeCap +"\n\000";
						demoStarted = 2;
					}
					if (demoStarted < 3 && svctime > startTime) {
						injectBuffer = "\011\ncl_capturevideo 1\n\000";
						demoStarted = 3;
					}
					if (!endIsReached && svctime > endTime) {
						injectBuffer = "\011\ncl_capturevideo 0\n\000";
						endIsReached = true;
					}
					if (endIsReached && !finalInjectionDone && svctime > (endTime + 1)) {
						injectBuffer = "\011\n" + injectAfterCap + "\n\000";
						finalInjectionDone = true;
					}
					if (finalInjectionDone && !disconnectIssued && svctime > (endTime + 2)) {
						injectBuffer = "\011\ndisconnect\n\000";
						disconnectIssued = true;
					}
					svcLoops++;
				}

				byte[] injectBufferAsBytes = null;
				try {
					injectBufferAsBytes = injectBuffer.getBytes("US-ASCII");
				} catch (UnsupportedEncodingException e) {
					throw new DemoCutterException("Could not convert String to bytes using US-ASCII charset!", e);
				}

				data = demoPacket.getOriginalData();
				if ((injectBufferAsBytes.length + data.length) < 65536) {
					data = DemoCutterUtils.mergeByteArrays(injectBufferAsBytes, data);
					injectBuffer = "";
				}
				
				byte[] newLengthLittleEndian = DemoCutterUtils.convertLittleEndian(data.length);
				try {
					this.outStream.write(newLengthLittleEndian);
					this.outStream.write(demoPacket.getAngles());
					this.outStream.write(data);
				} catch (IOException e) {
					throw new DemoCutterException("Unexpected I/O Exception occurred when writing to the cut demo", e);
				}

			}
			
			if (startTime < firstSvcTime) {
				throw new DemoCutterException("Start time for the demo is " + startTime + ", but demo doesn't start before " + firstSvcTime);
			}
			if (endTime > lastSvcTime) {
				throw new DemoCutterException("End time for the demo is " + endTime + ", but demo already stops at " + lastSvcTime);
			}
		} catch (DemoCutterException e) {
			throw e;
		} catch (Throwable e) {
			throw new DemoCutterException("Internal error in demo cutter sub-route (invalid demo file?)", e);
		} finally {
			try {
				this.outStream.close();
				this.inStream.close();
			} catch (IOException e) {}
		}
	}

	

	/**
	 * Seeks forward in the inStream until CDTRACK_SEPARATOR byte was reached.
	 * All the content is copied to the outStream.
	 */
	private void readCDTrack() {
		byte lastByte;
		try {
			while ((lastByte = inStream.readByte()) != CDTRACK_SEPARATOR) {
				this.outStream.write(lastByte);
			}
			this.outStream.write(CDTRACK_SEPARATOR);
		} catch (EOFException e) {
			throw new DemoCutterException("Unexpected EOF occurred when reading CD track of demo " + inFile.getPath(), e);
		}
		catch (IOException e) {
			throw new DemoCutterException("Unexpected I/O Exception occurred when reading CD track of demo " + inFile.getPath(), e);
		}
	}

	private void prepareStreams() {
		try {
			this.inStream = new DataInputStream(new FileInputStream(this.inFile));
		} catch (FileNotFoundException e) {
			throw new DemoCutterException("Could not open demo file " + inFile.getPath(), e);
		}
		
		try {
			this.outStream = new DataOutputStream(new FileOutputStream(this.outFile));
		} catch (FileNotFoundException e) {
			throw new DemoCutterException("Could not open demo file " + outFile.getPath(), e);
		}
	}
	
	private String checkInjectString(String injectionString) {
		while (injectionString.endsWith(";") || injectionString.endsWith("\n")) {
			injectionString = injectionString.substring(0, injectionString.length()-1);
		}
		return injectionString;
	}
}
