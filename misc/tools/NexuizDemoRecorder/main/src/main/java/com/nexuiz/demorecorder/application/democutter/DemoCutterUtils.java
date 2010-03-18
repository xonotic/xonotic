package com.nexuiz.demorecorder.application.democutter;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;


public class DemoCutterUtils {

	public static float byteArrayToFloat(byte[] array) {
		byte[] tmp = new byte[4];
  		System.arraycopy(array, 0, tmp, 0, 4);
		int accum = 0;
		int i = 0;
		for (int shiftBy = 0; shiftBy < 32; shiftBy += 8) {
			accum |= ((long) (tmp[i++] & 0xff)) << shiftBy;
		}
		return Float.intBitsToFloat(accum);
	}

	public static byte[] convertLittleEndian(int i) {
		ByteBuffer bb = ByteBuffer.allocate(4);
		bb.order(ByteOrder.LITTLE_ENDIAN);
		bb.putInt(i);
		return bb.array();
	}

	public static byte[] mergeByteArrays(byte[] array1, byte[] array2) {
		ByteBuffer bb = ByteBuffer.allocate(array1.length + array2.length);
		bb.put(array1);
		bb.put(array2);
		return bb.array();
	}

	public static int convertLittleEndian(byte[] b) {
		ByteBuffer bb = ByteBuffer.allocate(4);
		bb.order(ByteOrder.LITTLE_ENDIAN);
		bb.put(b);
		bb.position(0);
		return bb.getInt();
	}
}
