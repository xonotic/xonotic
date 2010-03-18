package com.nexuiz.demorecorder.ui;

import com.nexuiz.demorecorder.application.jobs.RecordJob;

public interface DemoRecorderUI {

	/**
	 * Called by the application layer to inform the GUI about the fact that
	 * one or more properties of the given job changed (most likely the status).
	 * The given job might also be new to the GUI.
	 * @param job the affected job
	 */
	public void RecordJobPropertiesChange(RecordJob job);
	
	/**
	 * Called by the application layer to inform the GUI that it finished
	 * recording all assigned jobs.
	 */
	public void recordingFinished();
}
