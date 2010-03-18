package com.nexuiz.demorecorder.application.jobs;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;

public class RecordsDoneJob implements Runnable {
	
	private DemoRecorderApplication appLayer;
	
	public RecordsDoneJob(DemoRecorderApplication appLayer) {
		this.appLayer = appLayer;
	}

	public void run() {
		this.appLayer.notifyAllJobsDone();
	}

}
