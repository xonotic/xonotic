package com.nexuiz.demorecorder.ui.swinggui.utils;

import java.io.File;

public class SwingGUIUtils {
	public static boolean isBooleanValue(String value) {
		if (value.equalsIgnoreCase("true") || value.equalsIgnoreCase("false")) {
			return true;
		}
		return false;
	}

	public static boolean isFileChooser(String value) {
		if (value.equalsIgnoreCase("filechooser")) {
			return true;
		}
		try {
			File file = new File(value);
			if (file.exists()) {
				return true;
			}
		} catch (Throwable e) {
		}
		return false;
	}
}
