package com.nexuiz.demorecorder.application.democutter;
import java.io.DataInputStream;
import java.io.EOFException;
import java.io.IOException;
import java.nio.ByteBuffer;


public class DemoPacket {
	
	private static final int DEMOMSG_CLIENT_TO_SERVER = 0x80000000;
	
	private DataInputStream inStream = null;
	private boolean isEndOfFile = false;
	private byte[] buffer = new byte[4]; //contains packet length
	private byte[] angles = new byte[12];
	private byte[] data;
	private int packetLength;
	private boolean isClientToServer = false;
	private float svcTime = -1;

	public DemoPacket(DataInputStream inStream) {
		this.inStream = inStream;
		
		try {
			inStream.readFully(buffer);
		} catch (EOFException e) {
			this.isEndOfFile = true;
			return;
		} catch (IOException e) {
			throw new DemoCutterException("Unexpected I/O Exception occurred when processing demo");
		}
		
		packetLength = DemoCutterUtils.convertLittleEndian(buffer);
		if ((packetLength & DEMOMSG_CLIENT_TO_SERVER) != 0) {
			packetLength = packetLength & ~DEMOMSG_CLIENT_TO_SERVER;

			this.isClientToServer = true;
			this.readAnglesAndData();
			return;
		}
		
		this.readAnglesAndData();
		
		// extract svc_time
		this.readSvcTime();
		
	}
	
	public boolean isEndOfFile() {
		return this.isEndOfFile;
	}
	
	public boolean isClientToServerPacket() {
		return this.isClientToServer;
	}
	
	public byte[] getOriginalLengthAsByte() {
		return this.buffer;
	}
	
	public byte[] getAngles() {
		return this.angles;
	}
	
	public byte[] getOriginalData() {
		return this.data;
	}
	
	public float getSvcTime() {
		return this.svcTime;
	}
	
	private void readAnglesAndData() {
		// read angles
		try {
			inStream.readFully(angles);
		} catch (EOFException e) {
			throw new DemoCutterException("Invalid Demo Packet");
		} catch (IOException e) {
			throw new DemoCutterException("Unexpected I/O Exception occurred when processing demo");
		}

		// read data
		data = new byte[packetLength];
		try {
			inStream.readFully(data);
		} catch (EOFException e) {
			throw new DemoCutterException("Invalid Demo Packet");
		} catch (IOException e) {
			throw new DemoCutterException("Unexpected I/O Exception occurred when processing demo");
		}
	}
	
	private void readSvcTime() {
		if (data[0] == 0x07) {
			ByteBuffer bb = ByteBuffer.allocate(4);
			bb.put(data, 1, 4);
			byte[] array = bb.array();
			this.svcTime = DemoCutterUtils.byteArrayToFloat(array);
		}
	}
}
