package com.nexuiz.demorecorder.main;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.ui.swinggui.SwingGUI;
import com.nexuiz.demorecorder.ui.swinggui.utils.ShowErrorDialogExceptionHandler;

public class Driver {
	
	public static void main(String[] args) {
		SwingGUI.setSystemLAF();
		Thread.setDefaultUncaughtExceptionHandler(new ShowErrorDialogExceptionHandler());
		DemoRecorderApplication appLayer = new DemoRecorderApplication();
		
		SwingGUI gui = new SwingGUI(appLayer);
		appLayer.addUserInterfaceListener(gui);
		
	}
}
