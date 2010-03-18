package com.nexuiz.demorecorder.application;

import java.io.File;
import java.io.IOException;

import org.jdesktop.swingx.JXErrorPane;
import org.jdesktop.swingx.error.ErrorInfo;

public class DemoRecorderUtils {
	
	public static void showNonCriticalErrorDialog(Throwable e) {
		if (!(e instanceof DemoRecorderException)) {
			e = new DemoRecorderException("Internal error", e);
		}
		ErrorInfo info = new ErrorInfo("Error occurred", e.getMessage(), null, null, e, null, null);
		JXErrorPane.showDialog(null, info);
	}
	
	/**
	 * Shows an error dialog that contains the stack trace, catching the exception so that the program flow
	 * won't be interrupted.
	 * This method will maybe wrap e in a DemoRecorderException with the given message.
	 * @param customMessage
	 * @param e
	 * @param wrapException set to true if Exception should be wrapped into a DemoRecorderException
	 */
	public static void showNonCriticalErrorDialog(String customMessage, Throwable e, boolean wrapException) {
		Throwable ex = e;
		if (wrapException && !(e instanceof DemoRecorderException)) {
			ex = new DemoRecorderException(customMessage, e);
		}
		
		ErrorInfo info = new ErrorInfo("Error occurred", ex.getMessage(), null, null, ex, null, null);
		JXErrorPane.showDialog(null, info);
	}
	
	public static File computeLocalFile(String subDir, String fileName) {
		String path = System.getProperty("user.dir");
		if (subDir != null && !subDir.equals("")) {
			path += File.separator + subDir;
		}
		path += File.separator + fileName;
		return new File(path);
	}
	
	/**
	 * Returns just the name of the file for a given File. E.g. if the File points to
	 * /home/someuser/somedir/somefile.end the function will return "somefile.end"
	 * @param file
	 * @return just the name of the file
	 */
	public static String getJustFileNameOfPath(File file) {
		String fileString = file.getAbsolutePath();
		int lastIndex = fileString.lastIndexOf(File.separator);
		String newString = fileString.substring(lastIndex+1, fileString.length());
		return newString;
	}
	
	/**
	 * Attempts to create an empty file (unless it already exists), including the creation
	 * of parent directories. If it succeeds to do so (or if the file already existed), true
	 * will be returned. Otherwise false will be returned
	 * @param file the file to be created
	 * @return true if file already existed or could successfully created, false otherwise
	 */
	public static boolean attemptFileCreation(File file) {
		if (!file.exists()) {
			try {
				file.createNewFile();
				return true;
			} catch (IOException e) {
				File parentDir = file.getParentFile();
				if (!parentDir.exists()) {
					try {
						if (parentDir.mkdirs() == true) {
							try {
								file.createNewFile();
								return true;
							} catch (Exception ex) {}
						}
					} catch (Exception ex) {}
				}
				return false;
			}
		} else {
			return true;
		}
	}
	
	public static final String getFileExtension(File file) {
		String fileName = file.getAbsolutePath();
		String ext = (fileName.lastIndexOf(".") == -1) ? "" : fileName.substring(fileName.lastIndexOf(".") + 1,fileName.length());
		return ext;
	}
}
