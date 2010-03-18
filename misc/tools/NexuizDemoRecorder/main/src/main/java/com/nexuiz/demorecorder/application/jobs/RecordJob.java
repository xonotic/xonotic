package com.nexuiz.demorecorder.application.jobs;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.DemoRecorderException;
import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.application.NDRPreferences;
import com.nexuiz.demorecorder.application.DemoRecorderApplication.Preferences;
import com.nexuiz.demorecorder.application.democutter.DemoCutter;
import com.nexuiz.demorecorder.application.democutter.DemoCutterException;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.application.plugins.EncoderPluginException;

public class RecordJob implements Runnable, Serializable {
	
	private static final long serialVersionUID = -4585637490345587912L;

	public enum State {
		WAITING, PROCESSING, ERROR, ERROR_PLUGIN, DONE
	}
	
	public static final String CUT_DEMO_FILE_SUFFIX = "_autocut";
	public static final String CUT_DEMO_CAPVIDEO_NAMEFORMAT_OVERRIDE = "autocap";
	public static final String CUT_DEMO_CAPVIDEO_NUMBER_OVERRIDE = "1234567";
	protected static final String[] VIDEO_FILE_ENDINGS = {"avi", "ogv"};
	
	private DemoRecorderApplication appLayer;
	protected String jobName;
	private int jobIndex;
	protected File enginePath;
	protected String engineParameters;
	protected File demoFile;
	protected String relativeDemoPath;
	protected File dpVideoPath;
	protected File videoDestination;
	protected String executeBeforeCap;
	protected String executeAfterCap;
	protected float startSecond;
	protected float endSecond;
	protected State state = State.WAITING;
	protected DemoRecorderException lastException = null;
	
	/**
	 * Points to the actual final file, including possible suffixes, e.g. _copy1, and the actualy ending
	 */
	protected File actualVideoDestination = null;
	/**
	 * Map that identifies the plug-in by its name (String) and maps to the plug-in's job-specific settings
	 */
	protected Map<String, Properties> encoderPluginSettings = new HashMap<String, Properties>();
	
	private List<File> cleanUpFiles = null;
	
	public RecordJob(
		DemoRecorderApplication appLayer,
		String jobName,
		int jobIndex,
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
		this.appLayer = appLayer;
		this.jobName = jobName;
		this.jobIndex = jobIndex;
		
		this.setEnginePath(enginePath);
		this.setEngineParameters(engineParameters);
		this.setDemoFile(demoFile);
		this.setRelativeDemoPath(relativeDemoPath);
		this.setDpVideoPath(dpVideoPath);
		this.setVideoDestination(videoDestination);
		this.setExecuteBeforeCap(executeBeforeCap);
		this.setExecuteAfterCap(executeAfterCap);
		this.setStartSecond(startSecond);
		this.setEndSecond(endSecond);
	}
	
	public RecordJob(){}
	
	/**
	 * Constructor that can be used by other classes such as job templates. Won't throw exceptions
	 * as it won't check the input for validity.
	 */
	protected RecordJob(
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
		this.jobIndex = -1;
		this.enginePath = enginePath;
		this.engineParameters = engineParameters;
		this.demoFile = demoFile;
		this.relativeDemoPath = relativeDemoPath;
		this.dpVideoPath = dpVideoPath;
		this.videoDestination = videoDestination;
		this.executeBeforeCap = executeBeforeCap;
		this.executeAfterCap = executeAfterCap;
		this.startSecond = startSecond;
		this.endSecond = endSecond;
	}
	
	public void execute() {
		if (this.state == State.PROCESSING) {
			return;
		}
		boolean errorOccurred = false;
		this.setState(State.PROCESSING);
		this.appLayer.fireUserInterfaceUpdate(this);
		cleanUpFiles = new ArrayList<File>();
		
		File cutDemo = computeCutDemoFile();
		cutDemo.delete(); //delete possibly old cutDemoFile
		
		EncoderPlugin recentEncoder = null;
		
		try {
			this.cutDemo(cutDemo);
			this.removeOldAutocaps();
			this.recordClip(cutDemo);
			this.moveRecordedClip();
			for (EncoderPlugin plugin : this.appLayer.getEncoderPlugins()) {
				recentEncoder = plugin;
				plugin.executeEncoder(this);
			}
		} catch (DemoRecorderException e) {
			errorOccurred = true;
			this.lastException = e;
			this.setState(State.ERROR);
		} catch (EncoderPluginException e) {
			errorOccurred = true;
			this.lastException = new DemoRecorderException("Encoder plug-in " + recentEncoder.getName() + " failed: "
					+ e.getMessage(), e);
			this.setState(State.ERROR_PLUGIN);
		} catch (Exception e) {
			errorOccurred = true;
			this.lastException = new DemoRecorderException("Executing job failed, click on details for more info", e);
		} finally {
			NDRPreferences preferences = this.appLayer.getPreferences();
			if (!Boolean.valueOf(preferences.getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.DO_NOT_DELETE_CUT_DEMOS))) {
				cleanUpFiles.add(cutDemo);
			}
			if (!errorOccurred) {
				this.setState(State.DONE);
			}
			this.cleanUpFiles();
			this.appLayer.fireUserInterfaceUpdate(this);
			this.appLayer.saveJobQueue();
		}
	}
	
	/**
	 * Will execute just the specified encoder plug-in on an already "done" job.
	 * @param pluginName
	 */
	public void executePlugin(EncoderPlugin plugin) {
		if (this.getState() != State.DONE) {
			return;
		}
		this.setState(State.PROCESSING);
		this.appLayer.fireUserInterfaceUpdate(this);
		
		try {
			plugin.executeEncoder(this);
			this.setState(State.DONE);
		} catch (EncoderPluginException e) {
			this.lastException = new DemoRecorderException("Encoder plug-in " + plugin.getName() + " failed: "
					+ e.getMessage(), e);
			this.setState(State.ERROR_PLUGIN);
		}
		
		this.appLayer.fireUserInterfaceUpdate(this);
	}
	
	private void cleanUpFiles() {
		try {
			for (File f : this.cleanUpFiles) {
				f.delete();
			}
		} catch (Exception e) {}
		
	}
	
	private void moveRecordedClip() {
		//1. Figure out whether the file is .avi or .ogv
		File sourceFile = null;
		for (String videoExtension : VIDEO_FILE_ENDINGS) {
			String fileString = this.dpVideoPath.getAbsolutePath() + File.separator + CUT_DEMO_CAPVIDEO_NAMEFORMAT_OVERRIDE
			+ CUT_DEMO_CAPVIDEO_NUMBER_OVERRIDE + "." + videoExtension;
			File videoFile = new File(fileString);
			if (videoFile.exists()) {
				sourceFile = videoFile;
				break;
			}
		}
		
		if (sourceFile == null) {
			String p = this.dpVideoPath.getAbsolutePath() + File.separator + CUT_DEMO_CAPVIDEO_NAMEFORMAT_OVERRIDE
			+ CUT_DEMO_CAPVIDEO_NUMBER_OVERRIDE;
			throw new DemoRecorderException("Could not locate the expected video file being generated by Nexuiz (should have been at "
					+ p + ".avi/.ogv");
		}
		cleanUpFiles.add(sourceFile);
		
		File destinationFile = null;
		NDRPreferences preferences = this.appLayer.getPreferences();
		String sourceFileExtension = DemoRecorderUtils.getFileExtension(sourceFile);
		String destinationFilePath = this.videoDestination + "." + sourceFileExtension;
		destinationFile = new File(destinationFilePath);
		if (destinationFile.exists()) {
			if (Boolean.valueOf(preferences.getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.OVERWRITE_VIDEO_FILE))) {
				if (!destinationFile.delete()) {
					throw new DemoRecorderException("Could not delete the existing video destinatin file " + destinationFile.getAbsolutePath()
							+ " (application setting to overwrite existing video files is enabled!)");
				}
			} else {
				destinationFilePath = this.videoDestination + "_copy" + this.getVideoDestinationCopyNr(sourceFileExtension) + "." + sourceFileExtension;
				destinationFile = new File(destinationFilePath);
			}
		}
		
		//finally move the file
		if (!sourceFile.renameTo(destinationFile)) {
			cleanUpFiles.add(destinationFile);
			throw new DemoRecorderException("Could not move the video file from " + sourceFile.getAbsolutePath()
					+ " to " + destinationFile.getAbsolutePath());
		}
		
		this.actualVideoDestination = destinationFile;
	}
	
	/**
	 * As destination video files, e.g. "test"[.avi] can already exist, we have to save the
	 * the video file to a file name such as test_copy1 or test_copy2.
	 * This function will figure out what the number (1, 2....) is.
	 * @return
	 */
	private int getVideoDestinationCopyNr(String sourceFileExtension) {
		int i = 1;
		File lastFile;
		while (true) {
			lastFile = new File(this.videoDestination + "_copy" + i + "." + sourceFileExtension);
			if (!lastFile.exists()) {
				break;
			}
			
			i++;
		}
		return i;
	}

	private File computeCutDemoFile() {
		String origFileString = this.demoFile.getAbsolutePath();
		int lastIndex = origFileString.lastIndexOf(File.separator);
		String autoDemoFileName = origFileString.substring(lastIndex+1, origFileString.length());
		//strip .dem ending
		autoDemoFileName = autoDemoFileName.substring(0, autoDemoFileName.length()-4);
		autoDemoFileName = autoDemoFileName + CUT_DEMO_FILE_SUFFIX + ".dem";
		String finalString = origFileString.substring(0, lastIndex) + File.separator + autoDemoFileName;
		File f = new File(finalString);
		
		return f;
	}
	
	private void cutDemo(File cutDemo) {
		String injectAtStart = "";
		String injectBeforeCap = "";
		String injectAfterCap = "";
		
		NDRPreferences preferences = this.appLayer.getPreferences();
		if (Boolean.valueOf(preferences.getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.DISABLE_RENDERING))) {
			injectAtStart += "r_render 0;";
			injectBeforeCap += "r_render 1;";
		}
		if (Boolean.valueOf(preferences.getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.DISABLE_SOUND))) {
			injectAtStart += "set _volume $volume;volume 0;";
			injectBeforeCap += "set volume $_volume;";
		}
		injectBeforeCap += this.executeBeforeCap + "\n";
		injectBeforeCap += "set _cl_capturevideo_nameformat $cl_capturevideo_nameformat;set _cl_capturevideo_number $cl_capturevideo_number;";
		injectBeforeCap += "cl_capturevideo_nameformat " + CUT_DEMO_CAPVIDEO_NAMEFORMAT_OVERRIDE + ";";
		injectBeforeCap += "cl_capturevideo_number " + CUT_DEMO_CAPVIDEO_NUMBER_OVERRIDE + ";";
		
		injectAfterCap += this.executeAfterCap + "\n";
		injectAfterCap += "cl_capturevideo_nameformat $_cl_capturevideo_nameformat;cl_capturevideo_number $_cl_capturevideo_number;";
		
		
		DemoCutter cutter = new DemoCutter();
		int fwdSpeedFirstStage, fwdSpeedSecondStage;
		try {
			fwdSpeedFirstStage = Integer.parseInt(preferences.getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.FFW_SPEED_FIRST_STAGE));
			fwdSpeedSecondStage = Integer.parseInt(preferences.getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.FFW_SPEED_SECOND_STAGE));
		} catch (NumberFormatException e) {
			throw new DemoRecorderException("Make sure that you specified valid numbers for the settings "
					+ Preferences.FFW_SPEED_FIRST_STAGE + " and " + Preferences.FFW_SPEED_SECOND_STAGE, e);
		}
		
		try {
			cutter.cutDemo(
				this.demoFile,
				cutDemo,
				this.startSecond,
				this.endSecond,
				injectAtStart,
				injectBeforeCap,
				injectAfterCap,
				fwdSpeedFirstStage,
				fwdSpeedSecondStage
			);
		} catch (DemoCutterException e) {
			throw new DemoRecorderException("Error occurred while trying to cut the demo: " + e.getMessage(), e);
		}
		
	}
	
	private void removeOldAutocaps() {
		for (String videoExtension : VIDEO_FILE_ENDINGS) {
			String fileString = this.dpVideoPath.getAbsolutePath() + File.separator + CUT_DEMO_CAPVIDEO_NAMEFORMAT_OVERRIDE
			+ CUT_DEMO_CAPVIDEO_NUMBER_OVERRIDE + "." + videoExtension;
			File videoFile = new File(fileString);
			cleanUpFiles.add(videoFile);
			if (videoFile.exists()) {
				if (!videoFile.delete()) {
					throw new DemoRecorderException("Could not delete old obsolete video file " + fileString);
				}
			}
		}
	}
	
	private void recordClip(File cutDemo) {
		Process nexProc;
		String demoFileName = DemoRecorderUtils.getJustFileNameOfPath(cutDemo);
		String execPath = this.enginePath.getAbsolutePath() + " " + this.engineParameters + " -demo "
						+ this.relativeDemoPath + "/" + demoFileName;
		File engineDir = this.enginePath.getParentFile();
		try {
			nexProc = Runtime.getRuntime().exec(execPath, null, engineDir);
			nexProc.getErrorStream();
			nexProc.getOutputStream();
			InputStream is = nexProc.getInputStream();
			InputStreamReader isr = new InputStreamReader(is);
			BufferedReader br = new BufferedReader(isr);
			while (br.readLine() != null) {
				//System.out.println(line);
			}
		} catch (IOException e) {
			throw new DemoRecorderException("I/O Exception occurred when trying to execute the Nexuiz binary", e);
		}
	}

	public void run() {
		this.execute();
	}
	
	public void setAppLayer(DemoRecorderApplication appLayer) {
		this.appLayer = appLayer;
	}

	public int getJobIndex() {
		return jobIndex;
	}

	public File getEnginePath() {
		return enginePath;
	}

	public void setEnginePath(File enginePath) {
		this.checkForProcessingState();
		if (enginePath == null || !enginePath.exists()) {
			throw new DemoRecorderException("Could not locate engine binary!");
		}
		if (!enginePath.canExecute()) {
			throw new DemoRecorderException("The file you specified is not executable!");
		}
		this.enginePath = enginePath.getAbsoluteFile();
	}

	public String getEngineParameters() {
		return engineParameters;
	}

	public void setEngineParameters(String engineParameters) {
		this.checkForProcessingState();
		if (engineParameters == null) {
			engineParameters = "";
		}
		this.engineParameters = engineParameters.trim();
	}

	public File getDemoFile() {
		return demoFile;
	}

	public void setDemoFile(File demoFile) {
		this.checkForProcessingState();
		if (demoFile == null) {
			throw new DemoRecorderException("Could not locate demo file!");
		}
		if (!demoFile.exists()) {
			throw new DemoRecorderException("Could not locate demo file!: " + demoFile.getAbsolutePath());
		}
		if (!doReadWriteTest(demoFile.getParentFile())) {
			throw new DemoRecorderException("The directory you specified for the demo to be recorded is not writable!");
		}
		if (!demoFile.getAbsolutePath().endsWith(".dem")) {
			throw new DemoRecorderException("The demo file you specified must have the ending .dem");
		}
		
		this.demoFile = demoFile.getAbsoluteFile();
	}

	public String getRelativeDemoPath() {
		return relativeDemoPath;
	}

	public void setRelativeDemoPath(String relativeDemoPath) {
		this.checkForProcessingState();
		if (relativeDemoPath == null) {
			relativeDemoPath = "";
		}
		
		//get rid of possible slashes
		while (relativeDemoPath.startsWith("/") || relativeDemoPath.startsWith("\\")) {
			relativeDemoPath = relativeDemoPath.substring(1, relativeDemoPath.length());
		}
		while (relativeDemoPath.endsWith("/") || relativeDemoPath.endsWith("\\")) {
			relativeDemoPath = relativeDemoPath.substring(0, relativeDemoPath.length() - 1);
		}
		
		this.relativeDemoPath = relativeDemoPath.trim();
	}

	public File getDpVideoPath() {
		return dpVideoPath;
	}

	public void setDpVideoPath(File dpVideoPath) {
		this.checkForProcessingState();
		if (dpVideoPath == null || !dpVideoPath.isDirectory()) {
			throw new DemoRecorderException("Could not locate the specified DPVideo directory!");
		}
		
		if (!this.doReadWriteTest(dpVideoPath)) {
			throw new DemoRecorderException("The DPVideo directory is not writable! It needs to be writable so that the file can be moved to its new location");
		}
		this.dpVideoPath = dpVideoPath.getAbsoluteFile();
	}

	public File getVideoDestination() {
		return videoDestination;
	}

	public void setVideoDestination(File videoDestination) {
		this.checkForProcessingState();
		//keep in mind, the parameter videoDestination points to the final avi/ogg file w/o extension!
		if (videoDestination == null || !videoDestination.getParentFile().isDirectory()) {
			throw new DemoRecorderException("Could not locate the specified video destination");
		}
		
		if (!this.doReadWriteTest(videoDestination.getParentFile())) {
			throw new DemoRecorderException("The video destination directory is not writable! It needs to be writable so that the file can be moved to its new location");
		}
		
		this.videoDestination = videoDestination.getAbsoluteFile();
	}

	public String getExecuteBeforeCap() {
		return executeBeforeCap;
	}

	public void setExecuteBeforeCap(String executeBeforeCap) {
		this.checkForProcessingState();
		if (executeBeforeCap == null) {
			executeBeforeCap = "";
		}
		executeBeforeCap = executeBeforeCap.trim();
		while (executeBeforeCap.endsWith(";")) {
			executeBeforeCap = executeBeforeCap.substring(0, executeBeforeCap.length()-1);
		}
		this.executeBeforeCap = executeBeforeCap;
	}

	public String getExecuteAfterCap() {
		return executeAfterCap;
	}

	public void setExecuteAfterCap(String executeAfterCap) {
		this.checkForProcessingState();
		if (executeAfterCap == null) {
			executeAfterCap = "";
		}
		executeAfterCap = executeAfterCap.trim();
		while (executeAfterCap.endsWith(";")) {
			executeAfterCap = executeAfterCap.substring(0, executeAfterCap.length()-1);
		}
		if (executeAfterCap.contains("cl_capturevideo_number") || executeAfterCap.contains("cl_capturevideo_nameformat")) {
			throw new DemoRecorderException("Execute after String cannot contain cl_capturevideo_number or _nameformat changes!");
		}
		this.executeAfterCap = executeAfterCap;
	}

	public float getStartSecond() {
		return startSecond;
	}

	public void setStartSecond(float startSecond) {
		this.checkForProcessingState();
		if (startSecond < 0) {
			throw new DemoRecorderException("Start second cannot be < 0");
		}
		this.startSecond = startSecond;
	}

	public float getEndSecond() {
		return endSecond;
	}

	public void setEndSecond(float endSecond) {
		this.checkForProcessingState();
		if (endSecond < this.startSecond) {
			throw new DemoRecorderException("End second cannot be < start second");
		}
		this.endSecond = endSecond;
	}

	public State getState() {
		return state;
	}

	public void setState(State state) {
		this.state = state;
		this.appLayer.fireUserInterfaceUpdate(this);
	}

	public String getJobName() {
		if (this.jobName == null || this.jobName.equals("")) {
			return "Job " + this.jobIndex;
		}
		return this.jobName;
	}
	
	public void setJobName(String jobName) {
		if (jobName == null || jobName.equals("")) {
			this.jobIndex = appLayer.getNewJobIndex();
			this.jobName = "Job " + this.jobIndex;
		} else {
			this.jobName = jobName;
		}
	}

	public DemoRecorderException getLastException() {
		return lastException;
	}
	
	/**
	 * Tests whether the given directory is writable by creating a file in there and deleting
	 * it again.
	 * @param directory
	 * @return true if directory is writable
	 */
	protected boolean doReadWriteTest(File directory) {
		boolean writable = false;
		String fileName = "tmp." + Math.random()*10000 + ".dat";
		File tempFile = new File(directory, fileName);
		try {
			writable = tempFile.createNewFile();
			if (writable) {
				tempFile.delete();
			}
		} catch (IOException e) {
			writable = false;
		}
		return writable;
	}
	
	private void checkForProcessingState() {
		if (this.state == State.PROCESSING) {
			throw new DemoRecorderException("Cannot modify this job while it is processing!");
		}
	}

	public Properties getEncoderPluginSettings(EncoderPlugin plugin) {
		if (this.encoderPluginSettings.containsKey(plugin.getName())) {
			return this.encoderPluginSettings.get(plugin.getName());
		} else {
			return new Properties();
		}
	}

	public void setEncoderPluginSetting(String pluginName, String pluginSettingKey, String value) {
		Properties p = this.encoderPluginSettings.get(pluginName);
		if (p == null) {
			p = new Properties();
			this.encoderPluginSettings.put(pluginName, p);
		}
		
		p.put(pluginSettingKey, value);
	}

	public Map<String, Properties> getEncoderPluginSettings() {
		return encoderPluginSettings;
	}

	public void setEncoderPluginSettings(Map<String, Properties> encoderPluginSettings) {
		this.encoderPluginSettings = encoderPluginSettings;
	}

	public File getActualVideoDestination() {
		return actualVideoDestination;
	}
	
	public void setActualVideoDestination(File actualVideoDestination) {
		this.actualVideoDestination = actualVideoDestination;
	}
}
