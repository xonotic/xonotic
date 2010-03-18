package com.nexuiz.demorecorder.application.plugins.impl.virtualdub;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.DemoRecorderException;
import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.application.jobs.RecordJob;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.application.plugins.EncoderPluginException;

public class VirtualDubPlugin implements EncoderPlugin {
	
	private static final String PLUGIN_NAME = "Virtual Dub";
	
	private static class Preferences {
		public static final String ENABLED = "Enabled";
		public static final String VIRTUAL_DUB_BINARY_PATH = "Path to vdub.exe";
		public static final String VCF_PER_JOB_LIMIT = "Max. number of VCFs per job";
		public static final String OUTPUT_FILE_MODE = "Output as suffix (0) or file (1)";
		public static final String EXTRA_OPTIONS = "Show extra options";
		
		public static final String[] GLOBAL_PREFERENCES_ORDER = {
			ENABLED,
			VIRTUAL_DUB_BINARY_PATH,
			VCF_PER_JOB_LIMIT,
			OUTPUT_FILE_MODE,
			EXTRA_OPTIONS
		};
		
		//job-specific preferences
		public static final String CLEAR_JOBCONTROL = "Clear VDub job control on first VCF";
		public static final String RENDER_OUTPUT = "VDub renders queued jobs";
		public static final String VCF_PATH = "Path to VCF file "; //x will be attached, e.g. "Path to VCF file 1"
		public static final String OUTPUT_SUFFIX = "Suffix for output file "; //x will be attached, e.g. "Suffix for output file 1"
		public static final String OUTPUT_FILE = "Output file "; //x will be attached
		public static final String USE_ENCODED_VIDEO = "<HTML><BODY>Use encoded video from VCF "; //x will be attached
		public static final String USE_ENCODED_VIDEO_2 = "<BR>for consecutive VCFs</BODY></HTML>";
		public static final String DELETE_ORIG_FILE = "Delete orig. file after processing VCF "; //x will be attached
	}
	
	private DemoRecorderApplication appLayer = null;
	private Properties globalDefaultPreferences = new Properties();
	
	public VirtualDubPlugin() {
		this.createPreferenceDefaultValues();
	}

	@Override
	public void executeEncoder(RecordJob job) throws EncoderPluginException {
		this.checkAppLayer();
		if (!this.isEnabled()) {
			return;
		}
		
		if (job.getActualVideoDestination() == null) {
			//should never happen... but just to make sure!
			throw new EncoderPluginException("Actual video destination is not set (should have been set when processing the job)");
		}
		
		if (!job.getActualVideoDestination().exists()) {
			throw new EncoderPluginException("Could not locate video file (source) at location "
					+ job.getActualVideoDestination().getAbsolutePath());
		}
		
		String limitStr = this.appLayer.getPreferences().getProperty(this.getName(), Preferences.VCF_PER_JOB_LIMIT);
		int vcfCounter;
		try {
			vcfCounter = Integer.valueOf(limitStr);
		} catch (NumberFormatException e) {
			throw new EncoderPluginException("Invalid value \"" + limitStr + "\" for setting " + Preferences.VCF_PER_JOB_LIMIT);
		}
		
		//check vdub.exe
		String vDubBinary = this.appLayer.getPreferences().getProperty(this.getName(), Preferences.VIRTUAL_DUB_BINARY_PATH);
		File vDubBinaryFile = new File(vDubBinary);
		if (!vDubBinaryFile.exists() || !vDubBinaryFile.canExecute()) {
			throw new EncoderPluginException("Invalid location for the vdub.exe: " + vDubBinary);
		}
		
		this.doEncoding(job, vcfCounter);
	}

	@Override
	public Properties getGlobalPreferences() {
		return this.globalDefaultPreferences;
	}

	@Override
	public String[] getGlobalPreferencesOrder() {
		return Preferences.GLOBAL_PREFERENCES_ORDER;
	}

	@Override
	public Properties getJobSpecificPreferences() {
		this.checkAppLayer();
		Properties jobSpecificPreferences = new Properties();
		
		//static properties
		jobSpecificPreferences.setProperty(Preferences.CLEAR_JOBCONTROL, "true");
		jobSpecificPreferences.setProperty(Preferences.RENDER_OUTPUT, "true");
		
		//dynamic properties
		String limitStr = this.appLayer.getPreferences().getProperty(this.getName(), Preferences.VCF_PER_JOB_LIMIT);
		try {
			int limit = Integer.valueOf(limitStr);
			if (limit > 0) {
				for (int i = 1; i <= limit; i++) {
					jobSpecificPreferences.setProperty(Preferences.VCF_PATH + i, "filechooser");
					if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.OUTPUT_FILE_MODE))) {
						//filechooser
						jobSpecificPreferences.setProperty(Preferences.OUTPUT_FILE + i, "filechooser");
					} else {
						//suffix
						jobSpecificPreferences.setProperty(Preferences.OUTPUT_SUFFIX + i, "_vdub" + i);
					}
					
					if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.EXTRA_OPTIONS))) {
						String useEncStringKey = Preferences.USE_ENCODED_VIDEO + i + Preferences.USE_ENCODED_VIDEO_2;
						jobSpecificPreferences.setProperty(useEncStringKey, "false");
						jobSpecificPreferences.setProperty(Preferences.DELETE_ORIG_FILE + i, "false");
					}
				}
			}
		} catch (NumberFormatException e) {
			throw new DemoRecorderException("Invalid value \"" + limitStr + "\" for setting " + Preferences.VCF_PER_JOB_LIMIT);
		}
		
		return jobSpecificPreferences;
	}
	
	@Override
	public String[] getJobSpecificPreferencesOrder() {
		this.checkAppLayer();
		List<String> preferencesOrderList = new ArrayList<String>();
		
		//static properties
		preferencesOrderList.add(Preferences.CLEAR_JOBCONTROL);
		preferencesOrderList.add(Preferences.RENDER_OUTPUT);
		
		//dynamic properties
		String limitStr = this.appLayer.getPreferences().getProperty(this.getName(), Preferences.VCF_PER_JOB_LIMIT);
		try {
			int limit = Integer.valueOf(limitStr);
			if (limit > 0) {
				for (int i = 1; i <= limit; i++) {
					preferencesOrderList.add(Preferences.VCF_PATH + i);
					if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.OUTPUT_FILE_MODE))) {
						//filechooser
						preferencesOrderList.add(Preferences.OUTPUT_FILE + i);
					} else {
						//suffix
						preferencesOrderList.add(Preferences.OUTPUT_SUFFIX + i);
					}
					
					if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.EXTRA_OPTIONS))) {
						String useEncStringKey = Preferences.USE_ENCODED_VIDEO + i + Preferences.USE_ENCODED_VIDEO_2;
						preferencesOrderList.add(useEncStringKey);
						preferencesOrderList.add(Preferences.DELETE_ORIG_FILE + i);
					}
				}
			}
		} catch (NumberFormatException e) {
			throw new DemoRecorderException("Invalid value \"" + limitStr + "\" for setting " + Preferences.VCF_PER_JOB_LIMIT);
		}
		
		Object[] arr = preferencesOrderList.toArray();
		String[] stringArr = new String[arr.length];
		for (int i = 0; i < arr.length; i++) {
			stringArr[i] = (String) arr[i];
		}
		
		return stringArr;
	}

	@Override
	public String getName() {
		return PLUGIN_NAME;
	}

	@Override
	public boolean isEnabled() {
		this.checkAppLayer();
		String enabledString = this.appLayer.getPreferences().getProperty(this.getName(), Preferences.ENABLED);
		return Boolean.valueOf(enabledString);
	}

	@Override
	public void setApplicationLayer(DemoRecorderApplication appLayer) {
		this.appLayer = appLayer;
	}
	
	private void checkAppLayer() {
		if (this.appLayer == null) {
			throw new DemoRecorderException("Error in plugin " + PLUGIN_NAME + "! Application layer not set!");
		}
	}
	
	private void createPreferenceDefaultValues() {
		this.globalDefaultPreferences.setProperty(Preferences.ENABLED, "false");
		this.globalDefaultPreferences.setProperty(Preferences.VIRTUAL_DUB_BINARY_PATH, "filechooser");
		this.globalDefaultPreferences.setProperty(Preferences.VCF_PER_JOB_LIMIT, "1");
		this.globalDefaultPreferences.setProperty(Preferences.OUTPUT_FILE_MODE, "false");
		this.globalDefaultPreferences.setProperty(Preferences.EXTRA_OPTIONS, "false");
	}
	
	private void doEncoding(RecordJob job, int vcfCounter) throws EncoderPluginException {
		boolean firstValidVCF = true;
		for (int i = 1; i <= vcfCounter; i++) {
			Properties jobSpecificSettings = job.getEncoderPluginSettings(this);
			String path = jobSpecificSettings.getProperty(Preferences.VCF_PATH + i);
			if (path != null) {
				File vcfFile = new File(path);
				if (vcfFile.exists()) {
					if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.OUTPUT_FILE_MODE))) {
						//filechooser
						String outputPath = jobSpecificSettings.getProperty(Preferences.OUTPUT_FILE + i, "filechooser");
						if (outputPath == null || outputPath.equals("") || outputPath.equals("filechoose")) {
							//user has not yet selected a file
							continue;
						}
					} else {
						//suffix
						String suffix = jobSpecificSettings.getProperty(Preferences.OUTPUT_SUFFIX + i);
						if (suffix == null || suffix.equals("")) {
							continue;
						}
					}
					BufferedWriter logWriter = this.getLogWriter(job.getJobName(), i);
					this.executeVDub(job, i, firstValidVCF, logWriter);
					firstValidVCF = false;
				}
			}
		}
	}
	
	private void executeVDub(RecordJob job, int index, boolean firstValidVCF, BufferedWriter logWriter) throws EncoderPluginException {
		String shellString = "";
		Properties jobSpecificSettings = job.getEncoderPluginSettings(this);
		File vcfFile = new File(jobSpecificSettings.getProperty(Preferences.VCF_PATH + index));
		File sourceFile = job.getActualVideoDestination();
		
		String vDubBinary = this.appLayer.getPreferences().getProperty(this.getName(), Preferences.VIRTUAL_DUB_BINARY_PATH);
		shellString += '"' + vDubBinary.trim() + '"';
		
		shellString += " /s " + '"' + vcfFile.getAbsolutePath() + '"';
		
		boolean clearJobControl = Boolean.valueOf(jobSpecificSettings.getProperty(Preferences.CLEAR_JOBCONTROL, "true"));
		if (clearJobControl && firstValidVCF) {
			shellString += " /c";
		}
		
		String outputFilePath = this.getOutputFilePath(job, index);
		File outputFile = new File(outputFilePath);
		shellString += " /p " + '"' + sourceFile.getAbsolutePath() + '"';
		shellString += " " + '"' + outputFilePath + '"';
		
		boolean renderOutput = Boolean.valueOf(jobSpecificSettings.getProperty(Preferences.RENDER_OUTPUT, "true"));
		if (renderOutput) {
			shellString += " /r";
		}
		
		shellString += " /x";
		
		try {
			logWriter.write("Executing commandline: " + shellString);
			logWriter.newLine();
			File vdubDir = new File(vDubBinary).getParentFile();
			Process vDubProc;
			vDubProc = Runtime.getRuntime().exec(shellString, null, vdubDir);
			vDubProc.getOutputStream();
			InputStreamReader isr = new InputStreamReader(vDubProc.getInputStream());
			BufferedReader bufferedInputStream = new BufferedReader(isr);
			String currentLine;
			while ((currentLine = bufferedInputStream.readLine()) != null) {
				logWriter.write(currentLine);
				logWriter.newLine();
			}
			InputStreamReader isrErr = new InputStreamReader(vDubProc.getErrorStream());
			BufferedReader bufferedInputStreamErr = new BufferedReader(isrErr);
			while ((currentLine = bufferedInputStreamErr.readLine()) != null) {
				logWriter.write(currentLine);
				logWriter.newLine();
			}
			logWriter.close();
			
		} catch (IOException e) {
			throw new EncoderPluginException("I/O Exception occurred when trying to execute the VDub binary or logging output", e);
		}
		
		//extra options: replace original video with encoded one, possibly delete original one
		if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.EXTRA_OPTIONS))) {
			String useEncStringKey = Preferences.USE_ENCODED_VIDEO + index + Preferences.USE_ENCODED_VIDEO_2;
			String useEncVideo = jobSpecificSettings.getProperty(useEncStringKey);
			File origFile = job.getActualVideoDestination();
			if (useEncVideo != null && Boolean.valueOf(useEncVideo)) {
				job.setActualVideoDestination(outputFile);
			}
			
			String deleteOrigFile = jobSpecificSettings.getProperty(Preferences.DELETE_ORIG_FILE + index);
			if (deleteOrigFile != null && Boolean.valueOf(deleteOrigFile)) {
				//only delete the original file if the encoded one exists:
				if (outputFile.exists() && outputFile.length() > 0) {
					origFile.delete();
				}
			}
		}
	}
	
	private String getOutputFilePath(RecordJob job, int index) {
		File sourceFile = job.getActualVideoDestination();
		String ext = DemoRecorderUtils.getFileExtension(sourceFile);
		String outputFilePath;
		Properties jobSpecificSettings = job.getEncoderPluginSettings(this);
		if (Boolean.valueOf(this.appLayer.getPreferences().getProperty(this.getName(), Preferences.OUTPUT_FILE_MODE))) {
			//filechooser
			outputFilePath = jobSpecificSettings.getProperty(Preferences.OUTPUT_FILE + index);
		} else {
			//suffix
			outputFilePath = sourceFile.getAbsolutePath();
			String suffix = jobSpecificSettings.getProperty(Preferences.OUTPUT_SUFFIX + index);
			int idx = outputFilePath.indexOf("." + ext);
			outputFilePath = outputFilePath.substring(0, idx);
			outputFilePath += suffix + "." + ext;
		}
		
		return outputFilePath;
	}
	
	private BufferedWriter getLogWriter(String jobName, int vcfIndex) throws EncoderPluginException {
		File logDir = DemoRecorderUtils.computeLocalFile(DemoRecorderApplication.LOGS_DIRNAME, "");
		if (jobName == null || jobName.equals("")) {
			jobName = "unnamed_job";
		}
		String path = logDir.getAbsolutePath() + File.separator + PLUGIN_NAME + '_' + jobName + '_' + "vcf" + vcfIndex + ".log";
		File logFile = new File(path);
		if (!DemoRecorderUtils.attemptFileCreation(logFile)) {
			throw new EncoderPluginException("Could not create log file for VDub job at location: " + path);
		}
		try {
			FileWriter fileWriter = new FileWriter(logFile);
			return new BufferedWriter(fileWriter);
		} catch (IOException e) {
			throw new EncoderPluginException("Could not create log file for VDub job at location: " + path, e);
		}
	}
}
