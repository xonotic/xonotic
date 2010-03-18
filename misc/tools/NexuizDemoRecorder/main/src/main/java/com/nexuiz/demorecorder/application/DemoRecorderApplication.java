package com.nexuiz.demorecorder.application;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.ServiceLoader;
import java.util.concurrent.CopyOnWriteArrayList;

import com.nexuiz.demorecorder.application.jobs.EncoderJob;
import com.nexuiz.demorecorder.application.jobs.RecordJob;
import com.nexuiz.demorecorder.application.jobs.RecordsDoneJob;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.ui.DemoRecorderUI;

public class DemoRecorderApplication {
	
	public static class Preferences {
		public static final String OVERWRITE_VIDEO_FILE = "Overwrite final video destination file if it exists";
		public static final String DISABLE_RENDERING = "Disable rendering while fast-forwarding";
		public static final String DISABLE_SOUND = "Disable sound while fast-forwarding";
		public static final String FFW_SPEED_FIRST_STAGE = "Fast-forward speed (first stage)";
		public static final String FFW_SPEED_SECOND_STAGE = "Fast-forward speed (second stage)";
		public static final String DO_NOT_DELETE_CUT_DEMOS = "Do not delete cut demos";
		public static final String JOB_NAME_APPEND_DUPLICATE = "Append this suffix to job-name when duplicating jobs";
		
		public static final String[] PREFERENCES_ORDER = {
			OVERWRITE_VIDEO_FILE,
			DISABLE_RENDERING,
			DISABLE_SOUND,
			FFW_SPEED_FIRST_STAGE,
			FFW_SPEED_SECOND_STAGE,
			DO_NOT_DELETE_CUT_DEMOS,
			JOB_NAME_APPEND_DUPLICATE
		};
	}
	
	public static final String PREFERENCES_DIRNAME = "settings";
	public static final String LOGS_DIRNAME = "logs";
	public static final String PLUGINS_DIRNAME = "plugins";
	public static final String APP_PREFERENCES_FILENAME = "app_preferences.xml";
	public static final String JOBQUEUE_FILENAME = "jobs.dat";
	
	public static final int STATE_WORKING = 0;
	public static final int STATE_IDLE = 1;
	
	private RecorderJobPoolExecutor poolExecutor;
	private List<RecordJob> jobs;
	private NDRPreferences preferences = null;
	private List<DemoRecorderUI> registeredUserInterfaces;
	private List<EncoderPlugin> encoderPlugins;
	private int state = STATE_IDLE;
	
	public DemoRecorderApplication() {
		poolExecutor = new RecorderJobPoolExecutor();
		jobs = new CopyOnWriteArrayList<RecordJob>();
		this.registeredUserInterfaces = new ArrayList<DemoRecorderUI>();
		this.encoderPlugins = new ArrayList<EncoderPlugin>();
		this.getPreferences();
		this.loadPlugins();
		this.configurePlugins();
		this.loadJobQueue();
	}
	
	public void setPreference(String category, String preference, boolean value) {
		this.preferences.setProperty(category, preference, String.valueOf(value));
	}
	
	public void setPreference(String category, String preference, int value) {
		this.preferences.setProperty(category, preference, String.valueOf(value));
	}
	
	public void setPreference(String category, String preference, String value) {
		this.preferences.setProperty(category, preference, value);
	}
	
	public NDRPreferences getPreferences() {
		if (this.preferences == null) {
			this.preferences = new NDRPreferences();
			this.createPreferenceDefaultValues();
			File preferencesFile = DemoRecorderUtils.computeLocalFile(PREFERENCES_DIRNAME, APP_PREFERENCES_FILENAME);
			if (preferencesFile.exists()) {
				FileInputStream fis = null;
				try {
					fis = new FileInputStream(preferencesFile);
					this.preferences.loadFromXML(fis);
				} catch (Exception e) {
					DemoRecorderUtils.showNonCriticalErrorDialog("Could not load the application preferences file!", e, true);
				}
			}
		}
		
		return this.preferences;
	}
	
	private void createPreferenceDefaultValues() {
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.OVERWRITE_VIDEO_FILE, "false");
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.DISABLE_RENDERING, "true");
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.DISABLE_SOUND, "true");
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.FFW_SPEED_FIRST_STAGE, "100");
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.FFW_SPEED_SECOND_STAGE, "10");
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.DO_NOT_DELETE_CUT_DEMOS, "false");
		this.preferences.setProperty(NDRPreferences.MAIN_APPLICATION, Preferences.JOB_NAME_APPEND_DUPLICATE, " duplicate");
	}
	
	public void savePreferences() {
		File preferencesFile = DemoRecorderUtils.computeLocalFile(PREFERENCES_DIRNAME, APP_PREFERENCES_FILENAME);
		if (!preferencesFile.exists()) {
			try {
				preferencesFile.createNewFile();
			} catch (IOException e) {
				File parentDir = preferencesFile.getParentFile();
				if (!parentDir.exists()) {
					try {
						if (parentDir.mkdirs() == true) {
							try {
								preferencesFile.createNewFile();
							} catch (Exception ex) {}
						}
					} catch (Exception ex) {}
				}
			}
		}
		
		if (!preferencesFile.exists()) {
			DemoRecorderException ex = new DemoRecorderException("Could not create the preferences file " + preferencesFile.getAbsolutePath());
			DemoRecorderUtils.showNonCriticalErrorDialog(ex);
			return;
		}
		
		FileOutputStream fos;
		try {
			fos = new FileOutputStream(preferencesFile);
		} catch (FileNotFoundException e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Could not create the preferences file " + preferencesFile.getAbsolutePath() + ". Unsufficient rights?", e, true);
			return;
		}
		try {
			this.preferences.storeToXML(fos, null);
		} catch (IOException e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Could not create the preferences file " + preferencesFile.getAbsolutePath(), e, true);
		}
	}
	
	public List<RecordJob> getRecordJobs() {
		return new ArrayList<RecordJob>(this.jobs);
	}
	
	public void startRecording() {
		if (this.state != STATE_WORKING) {
			this.state = STATE_WORKING;
			
			for (RecordJob currentJob : this.jobs) {
				if (currentJob.getState() == RecordJob.State.WAITING) {
					this.poolExecutor.runJob(currentJob);
				}
			}
			
			//notify ourself when job is done
			this.poolExecutor.runJob(new RecordsDoneJob(this));
		}
	}
	
	public void recordSelectedJobs(List<RecordJob> jobList) {
		if (this.state == STATE_IDLE) {
			this.state = STATE_WORKING;
			for (RecordJob currentJob : jobList) {
				if (currentJob.getState() == RecordJob.State.WAITING) {
					this.poolExecutor.runJob(currentJob);
				}
			}
			
			//notify ourself when job is done
			this.poolExecutor.runJob(new RecordsDoneJob(this));
		}
	}
	
	public void executePluginForSelectedJobs(EncoderPlugin plugin, List<RecordJob> jobList) {
		if (this.state == STATE_IDLE) {
			this.state = STATE_WORKING;
			for (RecordJob currentJob : jobList) {
				if (currentJob.getState() == RecordJob.State.DONE) {
					this.poolExecutor.runJob(new EncoderJob(currentJob, plugin));
				}
			}
			
			//notify ourself when job is done
			this.poolExecutor.runJob(new RecordsDoneJob(this));
		}
	}
	
	public void notifyAllJobsDone() {
		this.state = STATE_IDLE;
		
		//notify all UIs
		for (DemoRecorderUI currentUI : this.registeredUserInterfaces) {
			currentUI.recordingFinished();
		}
	}
	
	public synchronized void stopRecording() {
		if (this.state == STATE_WORKING) {
			//clear the queue of the threadpoolexecutor and add the GUI/applayer notify job again
			this.poolExecutor.clearUnfinishedJobs();
			this.poolExecutor.runJob(new RecordsDoneJob(this));
		}
	}
	
	public RecordJob createRecordJob(
		String name,
		File enginePath,
		String engineParameters,
		File demoFile,
		String relativeDemoPath,
		File dpVideoPath,
		File videoDestination,
		String executeBeforeCap,
		String executeAfterCap,
		float startSecond,
		float endSecond
	) {
		int jobIndex = -1;
		if (name == null || name.equals("")) {
			//we don't have a name, so use a generic one 
			jobIndex = this.getNewJobIndex();
			name = "Job " + jobIndex;
		} else {
			//just use the name and keep jobIndex at -1. Jobs with real names don't need an index
		}
		
		
		
		RecordJob newJob = new RecordJob(
			this,
			name,
			jobIndex,
			enginePath,
			engineParameters,
			demoFile,
			relativeDemoPath,
			dpVideoPath,
			videoDestination,
			executeBeforeCap,
			executeAfterCap,
			startSecond,
			endSecond
		);
		this.jobs.add(newJob);
		this.fireUserInterfaceUpdate(newJob);
		
		return newJob;
	}
	
	public synchronized boolean deleteRecordJob(RecordJob job) {
		if (!this.jobs.contains(job)) {
			return false;
		}
		
		//don't delete jobs that are scheduled for execution
		if (this.poolExecutor.getJobList().contains(job)) {
			return false;
		}
		
		this.jobs.remove(job);
		return true;
	}
	
	public void addUserInterfaceListener(DemoRecorderUI ui) {
		this.registeredUserInterfaces.add(ui);
	}
	
	/**
	 * Makes sure that all registered user interfaces can update their view/display.
	 * @param job either a job that's new to the UI, or one the UI already knows but of which details changed
	 */
	public void fireUserInterfaceUpdate(RecordJob job) {
		for (DemoRecorderUI ui : this.registeredUserInterfaces) {
			ui.RecordJobPropertiesChange(job);
		}
	}
	
	public int getNewJobIndex() {
		int jobIndex;
		if (this.jobs.size() == 0) {
			jobIndex = 1;
		} else {
			int greatestIndex = -1;
			for (RecordJob j : this.jobs) {
				if (j.getJobIndex() > greatestIndex) {
					greatestIndex = j.getJobIndex();
				}
			}
			if (greatestIndex == -1) {
				jobIndex = 1;
			} else {
				jobIndex = greatestIndex + 1;
			}
		}
		
		return jobIndex;
	}
	
	private void loadJobQueue() {
		File defaultFile = DemoRecorderUtils.computeLocalFile(PREFERENCES_DIRNAME, JOBQUEUE_FILENAME);
		this.loadJobQueue(defaultFile, true);
	}
	
	/**
	 * Loads the jobs from the given file path. If override is enabled, the previous
	 * job list will be overwritten with the newly loaded list. Otherwise the loaded jobs
	 * are added to the already existing list.
	 * @param path
	 * @param override
	 * @return the number of jobs loaded from the file
	 */
	@SuppressWarnings("unchecked")
	public int loadJobQueue(File path, boolean override) {
		if (!path.exists()) {
			return 0;
		}
		
		try {
			FileInputStream fin = new FileInputStream(path);
			ObjectInputStream ois = new ObjectInputStream(fin);
			List<RecordJob> newList = (List<RecordJob>) ois.readObject();
			for (RecordJob currentJob : newList) {
				currentJob.setAppLayer(this);
			}
			if (override) {
				this.jobs = newList;
			} else {
				this.jobs.addAll(newList);
			}
			return newList.size();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Could not load the job queue file " + path.getAbsolutePath(), e, true);
			return 0;
		}
	}
	
	public void saveJobQueue() {
		File defaultFile = DemoRecorderUtils.computeLocalFile(PREFERENCES_DIRNAME, JOBQUEUE_FILENAME);
		this.saveJobQueue(defaultFile);
	}
	
	public void saveJobQueue(File path) {
		if (!path.exists()) {
			try {
				path.createNewFile();
			} catch (IOException e) {
				File parentDir = path.getParentFile();
				if (!parentDir.exists()) {
					try {
						if (parentDir.mkdirs() == true) {
							try {
								path.createNewFile();
							} catch (Exception ex) {}
						}
					} catch (Exception ex) {}
				}
			}
		}
		
		String exceptionMessage = "Could not save the job queue file " + path.getAbsolutePath();
		
		if (!path.exists()) {
			DemoRecorderException ex = new DemoRecorderException(exceptionMessage);
			DemoRecorderUtils.showNonCriticalErrorDialog(ex);
			return;
		}
		
		//make sure that for the next start of the program the state is set to waiting again
		for (RecordJob job : this.jobs) {
			if (job.getState() == RecordJob.State.PROCESSING) {
				job.setState(RecordJob.State.WAITING);
			}
			job.setAppLayer(null); //we don't want to serialize the app layer!
		}
		
		try {
			FileOutputStream fout = new FileOutputStream(path);
			ObjectOutputStream oos = new ObjectOutputStream(fout);
			oos.writeObject(this.jobs);
			oos.close();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(exceptionMessage, e, true);
		}
		
		//we sometimes also save the jobqueue and don't exit the program, so restore the applayer again
		for (RecordJob job : this.jobs) {
			job.setAppLayer(this);
		}
	}
	
	public void shutDown() {
		this.poolExecutor.shutDown();
		this.savePreferences();
		this.saveJobQueue();
	}
	
	public int getState() {
		return this.state;
	}
	
	private void loadPlugins() {
		File pluginDir = DemoRecorderUtils.computeLocalFile(PLUGINS_DIRNAME, "");

		if (!pluginDir.exists()) {
			pluginDir.mkdir();
		}

		File[] jarFiles = pluginDir.listFiles();

		List<URL> urlList = new ArrayList<URL>();
		for (File f : jarFiles) {
			try {
				urlList.add(f.toURI().toURL());
			} catch (MalformedURLException ex) {}
		}
		ClassLoader parentLoader = Thread.currentThread().getContextClassLoader();
		URL[] urls = new URL[urlList.size()];
		urls = urlList.toArray(urls);
		URLClassLoader classLoader = new URLClassLoader(urls, parentLoader);
		
		ServiceLoader<EncoderPlugin> loader = ServiceLoader.load(EncoderPlugin.class, classLoader);
		for (EncoderPlugin implementation : loader) {
			this.encoderPlugins.add(implementation);
		}
	}
	
	private void configurePlugins() {
		for (EncoderPlugin plugin : this.encoderPlugins) {
			plugin.setApplicationLayer(this);
			Properties pluginPreferences = plugin.getGlobalPreferences();
			for (Object preference : pluginPreferences.keySet()) {
				String preferenceString = (String) preference;
				
				if (this.preferences.getProperty(plugin.getName(), preferenceString) == null) {
					String defaultValue = pluginPreferences.getProperty(preferenceString);
					this.preferences.setProperty(plugin.getName(), preferenceString, defaultValue);
				}
			}
		}
	}

	public List<EncoderPlugin> getEncoderPlugins() {
		return encoderPlugins;
	}
}
