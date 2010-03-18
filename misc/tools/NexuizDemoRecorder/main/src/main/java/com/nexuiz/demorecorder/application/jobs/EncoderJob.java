package com.nexuiz.demorecorder.application.jobs;

import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;

/**
 * Job for the ThreadPoolExecutor that will just call the encoder-plugin's execute
 * method.
 */
public class EncoderJob implements Runnable {
	
	private RecordJob job;
	private EncoderPlugin plugin;
	
	public EncoderJob(RecordJob job, EncoderPlugin plugin) {
		this.job = job;
		this.plugin = plugin;
	}

	@Override
	public void run() {
		this.job.executePlugin(this.plugin);
	}

}
