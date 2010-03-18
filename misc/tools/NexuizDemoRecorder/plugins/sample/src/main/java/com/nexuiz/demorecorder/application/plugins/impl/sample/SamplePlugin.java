package com.nexuiz.demorecorder.application.plugins.impl.sample;

import java.util.Properties;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.jobs.RecordJob;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.application.plugins.EncoderPluginException;

/**
 * This is a sample plug-in implementation. It does not really do anything, but it
 * is supposed to show you how to implement a plug-in and where to do what.
 * 
 * First of all, it is important that your final jar file (you can have Maven create
 * it for you) contains the META-INF folder (it will have that one anyway), and within
 * that folder you must have the folder "services", in which you must have a file called
 * com.nexuiz.demorecorder.application.plugins.EncoderPlugin (this is the fully
 * qualified name of the interface you need to implement, EncoderPlugin).
 * This file needs to contain just one line: the fully qualified name to your
 * implementation class!
 * 
 * Okay. The Nexuiz Demo Recorder (NDR) gives your plug-in 2 kinds of possibilities to
 * configure it ("set it up") from within the NDR. Configuring the plug-in is also 
 * referred to as "setting preferences". There are 
 * - Global preferences: these will be shown in the "Preferences" dialog of the NDR
 * - Job-specific preferences: these will be shown in the dialog you get when creating
 *   new jobs or templates, or when editing them
 * 
 * Once the NDR loaded your plug-in, the first thing it will do is to call 
 * setApplicationLayer(), handing your plug-in the reference to the app-layer. Make sure that
 * you save it in a private member variable!
 * 
 * NDR will ask your plug-in to tell it about its global and job-specific preferences that exist.
 * For each of these 2 kinds of preferences it will also ask you for the order in which you want
 * these settings to appear in dialogs.
 * 
 * The methods that ask you to return a Properties object: create a new Properties object and fill
 * it with KEYS (that identify the setting), and VALUES (reasonable default values). The app-layer
 * will save these "new" settings in the app_preferences.xml in the "settings" folder once NDR
 * is closed (this applies only to the global settings!). That just means that, later on, to figure
 * out whether the user changed settings from their default value, you need to ask the app-layer
 * for its preferences object (that might have been manipulated by the user using the GUI) and look
 * for "your" settings in that Properties object. A good example is the isEnabled() method.
 */
public class SamplePlugin implements EncoderPlugin {
	
	/**
	 *  Do not put the word "plug-in" in here, that would be redundant.
	 */
	private static final String PLUGIN_NAME = "Sample";
	
	/**
	 * Here we store our preferences. It is not necessary that these are in a inner-class, do it in
	 * your way if you want.
	 */
	private static class Preferences {
		/*
		 * Lets start with GLOBAL settings which will be seen in the Preferences dialog of the NDR
		 */
		public static final String ENABLED = "Enabled"; //we will need this! "Enabled" means that
									//that the preferences dialog will show the exact word "Enabled"
		
		public static final String SAMPLE_SETTING = "Some sample setting";
		
		/*
		 * Now we define the order in which we want these to be shown.
		 */
		public static final String[] GLOBAL_PREFERENCES_ORDER = {
			ENABLED,
			SAMPLE_SETTING
		};
		
		//job-specific preferences
		public static final String IN_USE_FOR_THIS_JOB = "Do something for this job";
		
		/*
		 * OK, so far we have actually only created labels. But we also need default values
		 * So let's have a function that sets the default values up.
		 */
		public static Properties globalDefaultPreferences = new Properties();
		public static void createPreferenceDefaultValues() {
			globalDefaultPreferences.setProperty(ENABLED, "false");
			globalDefaultPreferences.setProperty(SAMPLE_SETTING, "filechooser");
			/*
			 * Note that the values for the defaults can be:
			 * - "true" or "false", in this case the GUI will show a check-box
			 * - "filechooser", in this case the GUI will show a button that allows the user to select
			 *    a file
			 * - anything else (also empty string if you like): will show a text field in the GUI
			 *   (you are in charge of parsing it)
			 */
		}
		
	}
	
	private DemoRecorderApplication appLayer;
	
	/**
	 * You must only have a default constructor without parameters!
	 */
	public SamplePlugin() {
		Preferences.createPreferenceDefaultValues();
	}

	

	@Override
	public Properties getGlobalPreferences() {
		return Preferences.globalDefaultPreferences;
	}

	@Override
	public String[] getGlobalPreferencesOrder() {
		return Preferences.GLOBAL_PREFERENCES_ORDER;
	}

	@Override
	public Properties getJobSpecificPreferences() {
		/*
		 * This method is called whenever the dialog to create new jobs/templates (or edit them)
		 * is opened. This means that you can dynamically create the returned Properties object
		 * if you like, or you could of course also return something static.
		 */
		Properties preferences = new Properties();
		preferences.setProperty(Preferences.IN_USE_FOR_THIS_JOB, "true");
		return preferences;
	}

	@Override
	public String[] getJobSpecificPreferencesOrder() {
		String[] order = {Preferences.IN_USE_FOR_THIS_JOB};
		return order;
	}

	@Override
	public String getName() {
		return PLUGIN_NAME;
	}
	
	@Override
	public void setApplicationLayer(DemoRecorderApplication appLayer) {
		this.appLayer = appLayer;
	}

	@Override
	public boolean isEnabled() {
		/*
		 * Here we get the Properties object of the app-layer. Notice that this is actually a
		 * NDRPreferences object. It has a new method getProperty(String category, String key).
		 * The category is the name of our plug-in. The key is obviously our own ENABLED key.
		 */
		String enabledString = this.appLayer.getPreferences().getProperty(PLUGIN_NAME, Preferences.ENABLED);
		return Boolean.valueOf(enabledString);
	}
	
	@Override
	public void executeEncoder(RecordJob job) throws EncoderPluginException {
		/*
		 * This is where the party gets started.
		 * Of course you need to check whether your plug-in is enabled by the user, and whether the
		 * job-specific settings are set correctly. So let's do this now:
		 */
		if (!this.isEnabled()) {
			return;
		}
		
		if (job.getActualVideoDestination() == null) {
			//should never happen... but just to make sure!
			throw new EncoderPluginException("Actual video destination is not set (should have been set when processing the job)");
		}
		
		if (!job.getActualVideoDestination().exists()) {
			throw new EncoderPluginException("Could not locate recorded video file (source) at location "
					+ job.getActualVideoDestination().getAbsolutePath());
		}
		
		//check for a job-specific setting ... this time we need it from the job:
		Properties jobSpecificSettings = job.getEncoderPluginSettings(this);
		String isEnabled = jobSpecificSettings.getProperty(Preferences.IN_USE_FOR_THIS_JOB);
		if (!Boolean.valueOf(isEnabled)) {
			//the job does not want our plug-in to be executed, d'oh
			throw new EncoderPluginException("We are not enabled to do anything for this job :-(");
			//of course in a real implementation, instead of throwing an exception we'd just "return;"
		}
		
		/*
		 * Now we can start doing the work. What you'll normally do is to construct a big string that you then have executed
		 * Have a look at the VirtualDub plug-in implementation to see how I did it.
		 * 
		 * IMPORTANT: unless you parse the output of the console when executing a shell command (to check whether
		 * the encoder threw error messages at you), it is recommended that you create a log file of each job.
		 * The VirtualDub plug-in also provides an example of how to do that.
		 * 
		 * Also notice the use of the EncoderPluginException. Whenever something goes wrong, throw this exception.
		 * Note that there is also another constructor EncoderPluginException(String message, Throwable t) where you
		 * can attach the original exception.
		 */
	}

	

}
