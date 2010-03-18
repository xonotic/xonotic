package com.nexuiz.demorecorder.ui.swinggui;

import java.awt.Frame;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.Set;

import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JComponent;
import javax.swing.JDialog;
import javax.swing.JFileChooser;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTextField;

import net.miginfocom.swing.MigLayout;

import org.jdesktop.swingx.JXTitledSeparator;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.NDRPreferences;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.ui.swinggui.utils.SwingGUIUtils;

public class PreferencesDialog extends JDialog implements ActionListener {

	private static final long serialVersionUID = 7328399646538571333L;
	private Frame parentFrame;
	private DemoRecorderApplication appLayer;
	private NDRPreferences preferences;
	private Map<String, JComponent> dialogSettings;
	
	private JButton saveButton = new JButton("Save");
	private JButton cancelButton = new JButton("Cancel");
	
	public PreferencesDialog(Frame owner, DemoRecorderApplication appLayer) {
		super(owner, true);
		this.parentFrame = owner;
		this.appLayer = appLayer;
		this.preferences = appLayer.getPreferences();
		this.dialogSettings = new HashMap<String, JComponent>();
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);

		setTitle("Preferences");

		this.setupLayout();
	}

	private void setupLayout() {
		setLayout(new MigLayout("wrap 2", "[][::150,fill]"));
		
		//add heading
		JXTitledSeparator applicationHeading = new JXTitledSeparator("Application settings");
		getContentPane().add(applicationHeading, "span 2,grow");
		
		for (int i = 0; i < DemoRecorderApplication.Preferences.PREFERENCES_ORDER.length; i++) {
			String currentSetting = DemoRecorderApplication.Preferences.PREFERENCES_ORDER[i];
			if (this.preferences.getProperty(NDRPreferences.MAIN_APPLICATION, currentSetting) != null) {
				this.setupSingleSetting(NDRPreferences.MAIN_APPLICATION, currentSetting);
			}
		}
		
		//add plugin settings
		for (EncoderPlugin plugin : this.appLayer.getEncoderPlugins()) {
			String pluginName = plugin.getName();
			//only display settings if the plugin actually has any...
			Properties pluginPreferences = plugin.getGlobalPreferences();
			if (pluginPreferences.size() > 0) {
				//add heading
				JXTitledSeparator pluginHeading = new JXTitledSeparator(pluginName + " plugin settings");
				getContentPane().add(pluginHeading, "span 2,grow");
				
				for (String pluginKey : plugin.getGlobalPreferencesOrder()) {
					if (this.preferences.getProperty(pluginName, pluginKey) != null) {
						this.setupSingleSetting(pluginName, pluginKey);
					}
				}
			}
		}
		
		JPanel buttonPanel = new JPanel();
		buttonPanel.add(saveButton);
		buttonPanel.add(cancelButton);
		saveButton.addActionListener(this);
		cancelButton.addActionListener(this);
		getContentPane().add(buttonPanel, "span 2");
	}
	
	private void setupSingleSetting(String category, String setting) {
		getContentPane().add(new JLabel(setting + ":"));
		
		String value = this.preferences.getProperty(category, setting);
		if (SwingGUIUtils.isBooleanValue(value)) {
			JCheckBox checkbox = new JCheckBox();
			this.dialogSettings.put(NDRPreferences.getConcatenatedKey(category, setting), checkbox);
			getContentPane().add(checkbox);
		} else if (SwingGUIUtils.isFileChooser(value)) {
			final JFileChooser fc = new JFileChooser();
			fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
			JButton fcButton = new JButton("...");
			fcButton.addActionListener(new ActionListener() {
				@Override
				public void actionPerformed(ActionEvent e) {
					fc.showOpenDialog(PreferencesDialog.this);
				}
			});
			this.dialogSettings.put(NDRPreferences.getConcatenatedKey(category, setting), fc);
			getContentPane().add(fcButton);
		} else {
			JTextField textField = new JTextField();
			this.dialogSettings.put(NDRPreferences.getConcatenatedKey(category, setting), textField);
			getContentPane().add(textField);
		}
	}
	
	
	
	public void showDialog() {
		this.loadSettings();
		this.pack();
		this.setLocationRelativeTo(this.parentFrame);
		setResizable(false);
		this.setVisible(true);
	}
	
	/**
	 * Loads the settings from the application layer (and global plug-in settings) to the form.
	 */
	private void loadSettings() {
		Set<Object> keys = this.preferences.keySet();
		for (Object keyObj : keys) {
			String concatenatedKey = (String) keyObj;
			String value;
			JComponent component = null;
			if ((value = this.preferences.getProperty(concatenatedKey)) != null) {
				if (SwingGUIUtils.isBooleanValue(value)) {
					component = this.dialogSettings.get(concatenatedKey);
					if (component != null) {
						((JCheckBox) component).setSelected(Boolean.valueOf(value));
					}
				} else if (SwingGUIUtils.isFileChooser(value)) {
					component = this.dialogSettings.get(concatenatedKey);
					try {
						File selectedFile = new File(value);
						if (selectedFile.exists() && component != null) {
							((JFileChooser) component).setSelectedFile(selectedFile);
						}
					} catch (Throwable e) {}
					
				} else {
					component = this.dialogSettings.get(concatenatedKey);
					if (component != null) {
						((JTextField) component).setText(value);
					}
				}
			}
		}
	}

	@Override
	public void actionPerformed(ActionEvent e) {
		if (e.getSource() == cancelButton) {
			this.setVisible(false);
		} else if (e.getSource() == saveButton) {
			this.saveSettings();
		}
	}

	private void saveSettings() {
		Set<String> keys = this.dialogSettings.keySet();
		//remember, the keys are concatenated, containing both the category and actual key 
		for (String key : keys) {
			JComponent component = this.dialogSettings.get(key);
			if (component instanceof JCheckBox) {
				JCheckBox checkbox = (JCheckBox) component;
				this.appLayer.setPreference(NDRPreferences.getCategory(key), NDRPreferences.getKey(key), checkbox.isSelected());
			} else if (component instanceof JFileChooser) {
				JFileChooser fileChooser = (JFileChooser) component;
				if (fileChooser.getSelectedFile() != null) {
					String path = fileChooser.getSelectedFile().getAbsolutePath();
					this.appLayer.setPreference(NDRPreferences.getCategory(key), NDRPreferences.getKey(key), path);
				}
			} else if (component instanceof JTextField) {
				JTextField textField = (JTextField) component;
				this.appLayer.setPreference(NDRPreferences.getCategory(key), NDRPreferences.getKey(key), textField.getText());
			}
		}
		this.setVisible(false);
	}
}
