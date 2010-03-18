package com.nexuiz.demorecorder.application;

public class DemoRecorderException extends RuntimeException {
	
	private static final long serialVersionUID = 965053013957793155L;
	public DemoRecorderException(String message) {
		super(message);
	}
	public DemoRecorderException(String message, Throwable cause) {
		super(message, cause);
	}

}
