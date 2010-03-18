package com.nexuiz.demorecorder.ui.swinggui;

import java.io.File;

import com.nexuiz.demorecorder.application.DemoRecorderException;
import com.nexuiz.demorecorder.application.jobs.RecordJob;

public class RecordJobTemplate extends RecordJob {

	private static final long serialVersionUID = 8311386509410161395L;
	private String templateName;
	private String summary;

	public RecordJobTemplate(
		String templateName,
		String summary,
		String jobName,
		File enginePath,
		String engineParameters,
		File demoFile,
		String relativeDemoPath,
		File dpVideoPath,
		File videoDestination,
		String executeBeforeCap,
		String executeAfterCap
		) {
		super();
		
		/*
		 * Differences to jobs:
		 * - name and summary exist
		 * - "Demo file:" -> "Demo directory:"
		 * - no start/end second
		 */
		
		if (templateName == null || summary == null || jobName == null || enginePath == null || engineParameters == null || 
				demoFile == null || relativeDemoPath == null || dpVideoPath == null || videoDestination == null 
				|| executeBeforeCap == null || executeAfterCap == null) {
			throw new DemoRecorderException("Error: Make sure that you filled the necessary fields! (file choosers!)");
		}
		
		this.templateName = templateName;
		this.summary = summary;
		this.jobName = jobName;
		this.enginePath = enginePath;
		this.engineParameters = engineParameters;
		this.demoFile = demoFile;
		this.relativeDemoPath = relativeDemoPath;
		this.dpVideoPath = dpVideoPath;
		this.videoDestination = videoDestination;
		this.executeBeforeCap = executeBeforeCap;
		this.executeAfterCap = executeAfterCap;
	}

	public String getName() {
		return templateName;
	}

	public String getSummary() {
		return summary;
	}
	
	public void setName(String name) {
		this.templateName = name;
	}

	public void setSummary(String summary) {
		this.summary = summary;
	}

	/*
	 * (non-Javadoc)
	 * Overwrite this method because here we want to do the read/write test for the path directly
	 * (as this one already is the directory), and not its parent directory.
	 * @see com.nexuiz.demorecorder.application.jobs.RecordJob#setDemoFile(java.io.File)
	 */
	public void setDemoFile(File demoFile) {
		if (demoFile == null || !demoFile.exists()) {
			throw new DemoRecorderException("Could not locate demo file!");
		}
		if (!doReadWriteTest(demoFile)) {
			throw new DemoRecorderException("The directory you specified for the demo to be recorded is not writable!");
		}
		this.demoFile = demoFile.getAbsoluteFile();
	}
	
	/*
	 * (non-Javadoc)
	 * Overwrite this method because here we want to do the read/write test for the path directly
	 * (as this one already is the directory), and not its parent directory.
	 * @see com.nexuiz.demorecorder.application.jobs.RecordJob#setVideoDestination(java.io.File)
	 */
	public void setVideoDestination(File videoDestination) {
		//keep in mind, here videoDestination points to the destination directory, not the destination file
		if (videoDestination == null || !videoDestination.isDirectory()) {
			throw new DemoRecorderException("Could not locate the specified video destination directory");
		}
		
		if (!this.doReadWriteTest(videoDestination)) {
			throw new DemoRecorderException("The video destination directory is not writable! It needs to be writable so that the file can be moved to its new location");
		}
		
		this.videoDestination = videoDestination.getAbsoluteFile();
	}
	
	public String getJobName() {
		return this.jobName;
	}
	
	public void setJobName(String jobName) {
		this.jobName = jobName;
	}
}
