package com.nexuiz.demorecorder.application.plugins;

import java.util.Properties;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.jobs.RecordJob;

public interface EncoderPlugin {
	
	/**
	 * Makes the application layer known to the plug-in, which is required so that the plug-in
	 * can access the preferences of the application. Call this method first before using any
	 * of the others.
	 */
	public void setApplicationLayer(DemoRecorderApplication appLayer);

	/**
	 * Returns the name of the plug-in. Must not contain a "."
	 */
	public String getName();
	
	/**
	 * Returns true if the plug-in is enabled (checked from the preferences of the app layer)
	 * @return true if the plug-in is enabled
	 */
	public boolean isEnabled();
	
	/**
	 * Global preferences are preferences of a plug-in that are application-wide and not job-
	 * specific. They should be shown in a global preferences dialog.
	 * Use this method in order to tell the application layer and GUI which global settings your
	 * encoder plug-in offers, and set a reasonable default. Note that for the default-values being
	 * set you can either set to "true" or "false", any String (can be empty), or "filechooser" if
	 * you want the user to select a file. 
	 * @return
	 */
	public Properties getGlobalPreferences();
	
	/**
	 * In order to influence the order of settings being displayed to the user in a UI, return an array
	 * of all keys used in the Properties object returned in getGlobalPreferences(), with your desired
	 * order.
	 * @return
	 */
	public String[] getGlobalPreferencesOrder();
	
	/**
	 * Here you can return a Properties object that contains keys for values that can be specific to each
	 * individual RecordJob. 
	 * @return
	 */
	public Properties getJobSpecificPreferences();
	
	/**
	 * In order to influence the order of job-specific settings being displayed to the user in a UI,
	 * return an array of all keys used in the Properties object returned in getJobSpecificPreferences(), with
	 * your desired order.
	 * @return
	 */
	public String[] getJobSpecificPreferencesOrder();
	
	/**
	 * Will be called by the application layer when a job has been successfully recorded and moved to its
	 * final destination. This method has to perform the specific tasks your plug-in is supposed to do.
	 * @param job
	 * @throws EncoderPluginException
	 */
	public void executeEncoder(RecordJob job) throws EncoderPluginException;
}
