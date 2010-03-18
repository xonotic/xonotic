package com.nexuiz.demorecorder.application;

import java.util.Properties;

/**
 * Class that stores the application and global plug-in preferences of the Nexuiz
 * Demo Recorder application. Set and Get property methods have been modified to 
 * now supply a category.
 */
public class NDRPreferences extends Properties {
	
	private static final long serialVersionUID = 4363913054294979418L;
	private static final String CONCATENATOR = ".";
	/**
	 * Category that defines a setting to be a setting of the NDR application itself
	 * (and not of one of the plugins).
	 */
	public static final String MAIN_APPLICATION = "NDR";

	/**
     * Searches for the property with the specified key in this property list.
     * If the key is not found in this property list, the default property list,
     * and its defaults, recursively, are then checked. The method returns
     * <code>null</code> if the property is not found.
     *
     * @param   category the category of the setting
     * @param   key   the property key.
     * @return  the value in this property list with the specified category+key value.
     */
	public String getProperty(String category, String key) {
		return getProperty(getConcatenatedKey(category, key));
	}
	
	/**
     * Calls the <tt>Hashtable</tt> method <code>put</code>. Provided for
     * parallelism with the <tt>getProperty</tt> method. Enforces use of
     * strings for property keys and values. The value returned is the
     * result of the <tt>Hashtable</tt> call to <code>put</code>.
     *
     * @param category the category of the setting
     * @param key the key to be placed into this property list.
     * @param value the value corresponding to <tt>key</tt>.
     * @return     the previous value of the specified key in this property
     *             list, or <code>null</code> if it did not have one.
     */
	public void setProperty(String category, String key, String value) {
		setProperty(getConcatenatedKey(category, key), value);
	}
	
	/**
	 * Returns only the category of a key that is a concatenated string of category and key.
	 * @param concatenatedString
	 * @return
	 */
	public static String getCategory(String concatenatedString) {
		return concatenatedString.substring(0, concatenatedString.indexOf(CONCATENATOR));
	}
	
	public static String getKey(String concatenatedString) {
		return concatenatedString.substring(concatenatedString.indexOf(CONCATENATOR) + 1, concatenatedString.length());
	}
	
	public static String getConcatenatedKey(String category, String key) {
		return category + CONCATENATOR + key;
	}
}
