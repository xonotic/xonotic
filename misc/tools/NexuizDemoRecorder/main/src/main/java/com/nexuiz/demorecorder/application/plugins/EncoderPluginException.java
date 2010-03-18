package com.nexuiz.demorecorder.application.plugins;

public class EncoderPluginException extends Exception {

	private static final long serialVersionUID = 2200737027476726978L;

	public EncoderPluginException(String message) {
		super(message);
	}
	
	public EncoderPluginException(String message, Throwable t) {
		super(message, t);
	}
}
