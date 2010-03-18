package com.nexuiz.demorecorder.application;


import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import com.nexuiz.demorecorder.application.jobs.RecordJob;

public class RecorderJobPoolExecutor {
	
	private int poolSize = 1;
	private int maxPoolSize = 1;
	private long keepAliveTime = 10;
	private ThreadPoolExecutor threadPool = null;
	private ArrayBlockingQueue<Runnable> queue = null;

	public RecorderJobPoolExecutor() {
		queue = new ArrayBlockingQueue<Runnable>(99999);
		threadPool = new ThreadPoolExecutor(poolSize, maxPoolSize, keepAliveTime, TimeUnit.SECONDS, queue);
	}

	public void runJob(Runnable task) {
		threadPool.execute(task);
	}
	
	public void clearUnfinishedJobs() {
		threadPool.getQueue().clear();
	}

	public void shutDown() {
		threadPool.shutdownNow();
	}
	
	public synchronized List<RecordJob> getJobList() {
		List<RecordJob> list = new ArrayList<RecordJob>();
		for (Runnable job : this.queue) {
			try {
				RecordJob j = (RecordJob)job;
				list.add(j);
			} catch (ClassCastException e) {}
		}
		
		return list;
	}
}
