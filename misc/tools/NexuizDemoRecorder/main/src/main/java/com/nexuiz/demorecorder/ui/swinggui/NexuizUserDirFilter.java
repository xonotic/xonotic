package com.nexuiz.demorecorder.ui.swinggui;

import java.io.File;

import javax.swing.filechooser.FileFilter;

import com.nexuiz.demorecorder.application.DemoRecorderUtils;

/**
 * File filter that makes sure that the hidden .nexuiz directory is being shown in the
 * file dialog, but other hidden directories are not.
 */
public class NexuizUserDirFilter extends FileFilter {

	@Override
	public boolean accept(File f) {
		if (f.isHidden()) {
			if (f.isDirectory() && DemoRecorderUtils.getJustFileNameOfPath(f).equals(".nexuiz")) {
				return true;
			}
			return false; //don't show other hidden directories/files
		}
		return true;
	}

	@Override
	public String getDescription() {
		return null;
	}

}
