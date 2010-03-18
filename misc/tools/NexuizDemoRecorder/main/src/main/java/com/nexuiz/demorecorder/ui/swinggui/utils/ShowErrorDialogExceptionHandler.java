package com.nexuiz.demorecorder.ui.swinggui.utils;

import java.awt.Component;
import java.lang.Thread.UncaughtExceptionHandler;

import org.jdesktop.swingx.JXErrorPane;
import org.jdesktop.swingx.error.ErrorInfo;

public class ShowErrorDialogExceptionHandler implements UncaughtExceptionHandler {

	private static Component parentWindow = null;
	
	public void uncaughtException(Thread t, Throwable e) {
		ErrorInfo info = new ErrorInfo("Error occurred", e.getMessage(), null, null, e, null, null);
		JXErrorPane.showDialog(parentWindow, info);
	}

	public static void setParentWindow(Component c) {
		parentWindow = c;
	}
}
