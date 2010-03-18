package com.nexuiz.demorecorder.ui.swinggui;

import java.awt.Dimension;
import java.awt.Frame;
import java.awt.Toolkit;
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
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.ScrollPaneConstants;
import javax.swing.border.EmptyBorder;
import javax.swing.filechooser.FileFilter;

import net.miginfocom.swing.MigLayout;

import org.jdesktop.swingx.JXTable;
import org.jdesktop.swingx.JXTitledSeparator;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.application.NDRPreferences;
import com.nexuiz.demorecorder.application.jobs.RecordJob;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.ui.swinggui.tablemodels.RecordJobTemplatesTableModel;
import com.nexuiz.demorecorder.ui.swinggui.utils.SwingGUIUtils;

/**
 * Shows the dialog that allows to create a new job, create one from a template
 * or edit an existing job.
 */

public class JobDialog extends JDialog implements ActionListener {
	private static final long serialVersionUID = 6926246716804560522L;
	public static final int CREATE_NEW_JOB = 0;
	public static final int EDIT_JOB = 1;
	public static final int CREATE_NEW_TEMPLATE = 2;
	public static final int EDIT_TEMPLATE = 3;
	public static final int CREATE_JOB_FROM_TEMPLATE = 4;

	private DemoRecorderApplication appLayer;
	private RecordJobTemplatesTableModel tableModel;
//	private JXTable templatesTable;
	private Frame parentFrame;
	private int dialogType;
	private RecordJob job = null;
	private JPanel inputPanel;
	private JPanel buttonPanel;

	private JTextField templateNameField;
	private JTextField templateSummaryField;
	private JTextField enginePathField;
	private JButton enginePathChooserButton;
	private JTextField engineParameterField;
	private JTextField dpVideoDirField;
	private JButton dpVideoDirChooserButton;
	private JTextField relativeDemoPathField;
	private JTextField jobNameField;
	private JTextField demoFileField;
	private JButton demoFileChooserButton;
	private JTextField startSecondField;
	private JTextField endSecondField;
	private JTextArea execBeforeField;
	private JTextArea execAfterField;
	private JTextField videoDestinationField;
	private JButton videoDestinationChooserButton;
	
	private JButton createButton;
	private JButton cancelButton;
	
	//file choosers
	private JFileChooser enginePathFC;
	private JFileChooser dpVideoDirFC;
	private JFileChooser demoFileFC;
	private JFileChooser videoDestinationFC;
	
	private FileFilter userDirFilter = new NexuizUserDirFilter();
	
	private Map<String, JComponent> pluginDialogSettings = new HashMap<String, JComponent>();

	/**
	 * Constructor to create a dialog when creating a new job.
	 * @param owner
	 * @param appLayer
	 */
	public JobDialog(Frame owner, DemoRecorderApplication appLayer) {
		super(owner, true);
		this.parentFrame = owner;
		this.dialogType = CREATE_NEW_JOB;
		this.appLayer = appLayer;
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);

		setTitle("Create new job");

		this.setupLayout();
	}
	
	/**
	 * Constructor to create a dialog when creating a new template.
	 * @param owner
	 * @param dialogType
	 * @param appLayer
	 */
	public JobDialog(Frame owner, RecordJobTemplatesTableModel tableModel, JXTable templatesTable, DemoRecorderApplication appLayer) {
		super(owner, true);
		this.parentFrame = owner;
		this.dialogType = CREATE_NEW_TEMPLATE;
		this.tableModel = tableModel;
		this.appLayer = appLayer;
//		this.templatesTable = templatesTable; seems we don't need it
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);
		setTitle("Create new template");

		this.setupLayout();
	}
	
	/**
	 * Constructor to use when creating a new job from a template, or when editing a template.
	 * @param owner
	 * @param template
	 * @param type either CREATE_JOB_FROM_TEMPLATE or EDIT_TEMPLATE
	 */
	public JobDialog(Frame owner, RecordJobTemplate template, DemoRecorderApplication appLayer, int type) {
		super(owner, true);
		this.parentFrame = owner;
		
		this.job = template;
		this.appLayer = appLayer;
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);
		
		if (type != CREATE_JOB_FROM_TEMPLATE && type != EDIT_TEMPLATE) {
			throw new RuntimeException("Illegal paraameter \"type\"");
		}
		
		this.dialogType = type;
		if (type == CREATE_JOB_FROM_TEMPLATE) {
			setTitle("Create job from template");
		} else {
			setTitle("Edit template");
		}

		this.setupLayout();
	}
	
	/**
	 * Constructor to create a dialog to be used when editing an existing job.
	 * @param owner
	 * @param job
	 */
	public JobDialog(Frame owner, RecordJob job, DemoRecorderApplication appLayer) {
		super(owner, true);
		this.parentFrame = owner;
		this.dialogType = EDIT_JOB;
		this.appLayer = appLayer;
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);

		setTitle("Edit job");
		this.job = job;

		this.setupLayout();
	}
	
	
	
	public void showDialog() {
		this.pack();
		Toolkit t = Toolkit.getDefaultToolkit();
		Dimension screenSize = t.getScreenSize();
		if (getHeight() > screenSize.height) {
			Dimension newPreferredSize = getPreferredSize();
			newPreferredSize.height = screenSize.height - 100;
			setPreferredSize(newPreferredSize);
			this.pack();
		}
		this.setLocationRelativeTo(this.parentFrame);
		this.setVisible(true);
	}

	private void setupLayout() {
//		setLayout(new MigLayout("wrap 1", "[grow,fill]", "[]20[]"));
		setLayout(new MigLayout("wrap 1", "[grow,fill]", "[][]"));
		this.setupInputMask();
		this.setupButtonPart();

	}

	private void setupInputMask() {
		inputPanel = new JPanel(new MigLayout("insets 0,wrap 3", "[][250::,grow,fill][30::]"));
		JScrollPane inputScrollPane = new JScrollPane(inputPanel, ScrollPaneConstants.VERTICAL_SCROLLBAR_AS_NEEDED, ScrollPaneConstants.HORIZONTAL_SCROLLBAR_NEVER);
		inputScrollPane.setBorder(new EmptyBorder(0,0,0,0));
		
		JXTitledSeparator environmentHeading = new JXTitledSeparator("Environment settings");
		inputPanel.add(environmentHeading, "span 3,grow");

		this.setupTemplateNameAndSummary();
		this.setupEnginePath();
		this.setupEngineParameters();
		this.setupDPVideoDir();
		this.setupRelativeDemoPath();

		JXTitledSeparator jobSettingsHeading = new JXTitledSeparator("Job settings");
		inputPanel.add(jobSettingsHeading, "span 3,grow");

		this.setupJobName();
		this.setupDemoFile();
		this.setupStartSecond();
		this.setupEndSecond();
		this.setupExecBefore();
		this.setupExecAfter();
		this.setupVideoDestination();
		
		this.setupPluginPreferences();

		getContentPane().add(inputScrollPane);
	}
	
	private void setupTemplateNameAndSummary() {
		if (this.dialogType != CREATE_NEW_TEMPLATE && this.dialogType != EDIT_TEMPLATE) {
			return;
		}
		
		//layout stuff
		inputPanel.add(new JLabel("Template name:"));
		templateNameField = new JTextField();
		inputPanel.add(templateNameField, "wrap");
		
		inputPanel.add(new JLabel("Summary:"));
		templateSummaryField = new JTextField();
		inputPanel.add(templateSummaryField, "wrap");
		
		//UI logic stuff
		if (this.dialogType == EDIT_TEMPLATE) {
			RecordJobTemplate template = (RecordJobTemplate) this.job;
			templateNameField.setText(template.getName());
			templateSummaryField.setText(template.getSummary());
		}
	}
	
	private void setupEnginePath() {
		//layout stuff
		inputPanel.add(new JLabel("Engine:"));
		enginePathField = new JTextField();
		enginePathField.setEditable(false);
		inputPanel.add(enginePathField);
		enginePathChooserButton = new FileChooserButton();
		inputPanel.add(enginePathChooserButton);
		
		//UI logic stuff
		this.enginePathFC = createConfiguredFileChooser();
		enginePathChooserButton.addActionListener(this);
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			this.enginePathFC.setSelectedFile(this.job.getEnginePath());
			this.enginePathField.setText(this.job.getEnginePath().getAbsolutePath());
		}
	}
	
	private void setupEngineParameters() {
		//layout stuff
		inputPanel.add(new JLabel("Engine parameters:"));
		engineParameterField = new JTextField();
		inputPanel.add(engineParameterField, "wrap");
		
		//UI logic stuff
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			engineParameterField.setText(this.job.getEngineParameters());
		}
	}
	
	private void setupDPVideoDir() {
		//layout stuff
		inputPanel.add(new JLabel("DPVideo directory:"));
		dpVideoDirField = new JTextField();
		dpVideoDirField.setEditable(false);
		inputPanel.add(dpVideoDirField);
		dpVideoDirChooserButton = new FileChooserButton();
		inputPanel.add(dpVideoDirChooserButton);
		
		//UI logic stuff
		dpVideoDirChooserButton.addActionListener(this);
		this.dpVideoDirFC = createConfiguredFileChooser();
		this.dpVideoDirFC.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			this.dpVideoDirFC.setSelectedFile(this.job.getDpVideoPath());
			this.dpVideoDirField.setText(this.job.getDpVideoPath().getAbsolutePath());
		}
	}
	
	private void setupRelativeDemoPath() {
		//layout stuff
		inputPanel.add(new JLabel("Relative demo path:"));
		relativeDemoPathField = new JTextField();
		inputPanel.add(relativeDemoPathField, "wrap 20");
		
		//UI logic stuff
		if (this.dialogType == CREATE_NEW_JOB || this.dialogType == CREATE_NEW_TEMPLATE) {
			relativeDemoPathField.setText("demos");
		}
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			relativeDemoPathField.setText(this.job.getRelativeDemoPath());
		}
	}
	
	private void setupJobName() {
		inputPanel.add(new JLabel("Job name:"));
		
		jobNameField = new JTextField();
		inputPanel.add(jobNameField, "wrap");
		
		//UI logic stuff
		if (this.dialogType != CREATE_NEW_TEMPLATE && this.dialogType != CREATE_NEW_JOB) {
			jobNameField.setText(this.job.getJobName());
		}
	}
	
	private void setupDemoFile() {
		String label;
		if (this.dialogType == CREATE_NEW_JOB || this.dialogType == EDIT_JOB || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			label = "Demo file:";
		} else {
			label = "Demo directory:";
		}
		
		//layout stuff
		inputPanel.add(new JLabel(label));
		demoFileField = new JTextField();
		demoFileField.setEditable(false);
		inputPanel.add(demoFileField);
		demoFileChooserButton = new FileChooserButton();
		inputPanel.add(demoFileChooserButton);
		
		//UI logic stuff
		this.demoFileFC = createConfiguredFileChooser();
		demoFileChooserButton.addActionListener(this);
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			if (this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
				this.demoFileFC.setCurrentDirectory(this.job.getDemoFile());
			} else {
				this.demoFileFC.setSelectedFile(this.job.getDemoFile());
			}
			
			this.demoFileField.setText(this.job.getDemoFile().getAbsolutePath());
		}
		
		//only specify directories for templates
		if (this.dialogType == CREATE_NEW_TEMPLATE || this.dialogType == EDIT_TEMPLATE) {
			this.demoFileFC.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		}
	}
	
	private void setupStartSecond() {
		//only exists for jobs, not for templates
		if (this.dialogType != CREATE_NEW_JOB && this.dialogType != EDIT_JOB && this.dialogType != CREATE_JOB_FROM_TEMPLATE) {
			return;
		}
		
		//layout stuff
		inputPanel.add(new JLabel("Start second:"));
		startSecondField = new JTextField();
		inputPanel.add(startSecondField, "wrap");
		
		//UI logic stuff
		if (this.dialogType == EDIT_JOB) {
			startSecondField.setText(String.valueOf( this.job.getStartSecond() ));
		}
	}
	
	private void setupEndSecond() {
		//only exists for jobs, not for templates
		if (this.dialogType != CREATE_NEW_JOB && this.dialogType != EDIT_JOB && this.dialogType != CREATE_JOB_FROM_TEMPLATE) {
			return;
		}
		
		//layout stuff
		inputPanel.add(new JLabel("End second:"));
		endSecondField = new JTextField();
		inputPanel.add(endSecondField, "wrap");
		
		//UI logic stuff
		if (this.dialogType == EDIT_JOB) {
			endSecondField.setText(String.valueOf( this.job.getEndSecond() ));
		}
	}
	
	private void setupExecBefore() {
		//layout stuff
		inputPanel.add(new JLabel("Exec before capture:"));
		execBeforeField = new JTextArea(3, 1);
		inputPanel.add(new JScrollPane(execBeforeField), "wrap");
		
		//UI logic stuff
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			execBeforeField.setText(this.job.getExecuteBeforeCap());
		}
	}
	
	private void setupExecAfter() {
		//layout stuff
		inputPanel.add(new JLabel("Exec after capture:"));
		execAfterField = new JTextArea(3, 1);
		inputPanel.add(new JScrollPane(execAfterField), "wrap");
		
		//UI logic stuff
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			execAfterField.setText(this.job.getExecuteAfterCap());
		}
	}
	
	private void setupVideoDestination() {
		//layout stuff
		inputPanel.add(new JLabel("Video destination:"));
		videoDestinationField = new JTextField();
		videoDestinationField.setEditable(false);
		inputPanel.add(videoDestinationField);
		videoDestinationChooserButton = new FileChooserButton();
		inputPanel.add(videoDestinationChooserButton, "wrap 20");
		
		//UI logic stuff
		videoDestinationChooserButton.addActionListener(this);
		this.videoDestinationFC = createConfiguredFileChooser();
		if (this.dialogType == EDIT_JOB || this.dialogType == EDIT_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			if (this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
				this.videoDestinationFC.setCurrentDirectory(this.job.getVideoDestination());
			} else {
				this.videoDestinationFC.setSelectedFile(this.job.getVideoDestination());
			}
			
			this.videoDestinationField.setText(this.job.getVideoDestination().getAbsolutePath());
		}
		if (this.dialogType == CREATE_NEW_TEMPLATE || this.dialogType == EDIT_TEMPLATE) {
			this.videoDestinationFC.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
		}
	}
	
	private void setupPluginPreferences() {
		for (EncoderPlugin plugin : this.appLayer.getEncoderPlugins()) {
			String pluginName = plugin.getName();
			//only display settings if the plugin actually has any...
			Properties jobSpecificDefaultPluginPreferences = plugin.getJobSpecificPreferences();
			Properties jobPluginPreferences = null;
			if (this.job != null) {
				jobPluginPreferences = this.job.getEncoderPluginSettings(plugin);
			}
			if (jobSpecificDefaultPluginPreferences.size() > 0 && plugin.isEnabled()) {
				//add heading
				JXTitledSeparator pluginHeading = new JXTitledSeparator(pluginName + " plugin settings");
				inputPanel.add(pluginHeading, "span 3,grow");
				
				for (String pluginPreferenceKey : plugin.getJobSpecificPreferencesOrder()) {
					String value = jobSpecificDefaultPluginPreferences.getProperty(pluginPreferenceKey);
					if (this.job != null) {
						if (jobPluginPreferences.containsKey(pluginPreferenceKey)) {
							value = jobPluginPreferences.getProperty(pluginPreferenceKey);
						}
					}
					
					this.setupSinglePluginSetting(plugin, pluginPreferenceKey, value);
				}
			}
		}
	}
	
	private void setupSinglePluginSetting(EncoderPlugin plugin, String key, String value) {
		inputPanel.add(new JLabel(key + ":"));
		
		if (SwingGUIUtils.isBooleanValue(value)) {
			JCheckBox checkbox = new JCheckBox();
			checkbox.setSelected(Boolean.valueOf(value));
			inputPanel.add(checkbox, "wrap");
			this.pluginDialogSettings.put(NDRPreferences.getConcatenatedKey(plugin.getName(), key), checkbox);
		} else if (SwingGUIUtils.isFileChooser(value)) {
			final JFileChooser fc = new JFileChooser();
			fc.setFileSelectionMode(JFileChooser.FILES_AND_DIRECTORIES);
			JButton fcButton = new JButton("...");
			final JTextField filePathField = new JTextField();
			filePathField.setEditable(false);
			inputPanel.add(filePathField);
			fcButton.addActionListener(new ActionListener() {
				@Override
				public void actionPerformed(ActionEvent e) {
					int returnValue = fc.showOpenDialog(JobDialog.this);
					if (returnValue == JFileChooser.APPROVE_OPTION) {
						File selectedFile = fc.getSelectedFile();
						filePathField.setText(selectedFile.getAbsolutePath());
					}
				}
			});
			
			try {
				File selectedFile = new File(value);
				if (selectedFile.exists()) {
					fc.setSelectedFile(selectedFile);
					filePathField.setText(selectedFile.getAbsolutePath());
				}
			} catch (Throwable e) {}
			this.pluginDialogSettings.put(NDRPreferences.getConcatenatedKey(plugin.getName(), key), fc);
			inputPanel.add(fcButton);
		} else {
			//textfield
			JTextField textField = new JTextField();
			textField.setText(value);
			this.pluginDialogSettings.put(NDRPreferences.getConcatenatedKey(plugin.getName(), key), textField);
			inputPanel.add(textField, "wrap");
		}
	}

	private void setupButtonPart() {
		String createButtonText;
		if (this.dialogType == CREATE_NEW_JOB || this.dialogType == CREATE_NEW_TEMPLATE || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
			createButtonText = "Create";
		} else {
			createButtonText = "Save";
		}
		buttonPanel = new JPanel(new MigLayout("insets 0"));
		createButton = new JButton(createButtonText);
		createButton.addActionListener(this);
		cancelButton = new JButton("Cancel");
		cancelButton.addActionListener(this);
		
		buttonPanel.add(createButton);
		buttonPanel.add(cancelButton);

		getContentPane().add(buttonPanel);
	}
	
	
	public void actionPerformed(ActionEvent e) {
		if (e.getSource() == enginePathChooserButton) {
			int returnValue = this.enginePathFC.showOpenDialog(this);
			if (returnValue == JFileChooser.APPROVE_OPTION) {
				File selectedFile = this.enginePathFC.getSelectedFile();
				this.enginePathField.setText(selectedFile.getAbsolutePath());
			}
		} else if (e.getSource() == dpVideoDirChooserButton) {
			int returnValue = this.dpVideoDirFC.showOpenDialog(this);
			if (returnValue == JFileChooser.APPROVE_OPTION) {
				File selectedFile = this.dpVideoDirFC.getSelectedFile();
				this.dpVideoDirField.setText(selectedFile.getAbsolutePath());
			}
		} else if (e.getSource() == demoFileChooserButton) {
			int returnValue = this.demoFileFC.showOpenDialog(this);
			if (returnValue == JFileChooser.APPROVE_OPTION) {
				File selectedFile = this.demoFileFC.getSelectedFile();
				if (this.dialogType == CREATE_NEW_JOB || this.dialogType == EDIT_JOB || this.dialogType == CREATE_JOB_FROM_TEMPLATE) {
					this.demoFileField.setText(DemoRecorderUtils.getJustFileNameOfPath(selectedFile));
				} else {
					//template, show full path of directory
					this.demoFileField.setText(selectedFile.getAbsolutePath());
				}
				
			}
		} else if (e.getSource() == videoDestinationChooserButton) {
			int returnValue = this.videoDestinationFC.showSaveDialog(this);
			if (returnValue == JFileChooser.APPROVE_OPTION) {
				File selectedFile = this.videoDestinationFC.getSelectedFile();
				this.videoDestinationField.setText(selectedFile.getAbsolutePath());
			}
		} else if (e.getSource() == createButton) {
			switch (this.dialogType) {
			case CREATE_NEW_JOB:
			case CREATE_JOB_FROM_TEMPLATE:
				this.requestNewRecordJob(); break;
			case CREATE_NEW_TEMPLATE:
				this.createNewTemplate();
				break;
			case EDIT_JOB:
				this.editJob();
				break;
			case EDIT_TEMPLATE:
				this.editTemplate();
				break;
			}
		} else if (e.getSource() == cancelButton) {
			dispose();
		}
	}
	
	private void requestNewRecordJob() {
		float startSecond, endSecond = -1;
		try {
			startSecond = Float.valueOf(this.startSecondField.getText());
			endSecond = Float.valueOf(this.endSecondField.getText());
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Make sure that start and end second are floating point numbers", e, true);
			return;
		}
		
		try {
			RecordJob j = this.appLayer.createRecordJob(
				this.jobNameField.getText(),
				this.enginePathFC.getSelectedFile(),
				this.engineParameterField.getText(),
				this.demoFileFC.getSelectedFile(),
				this.relativeDemoPathField.getText(),
				this.dpVideoDirFC.getSelectedFile(),
				this.videoDestinationFC.getSelectedFile(),
				this.execBeforeField.getText(),
				this.execAfterField.getText(),
				startSecond,
				endSecond
			);
			this.saveEncoderPluginSettings(j);
			dispose();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(e);
			return;
		}
		
	}
	
	private void editJob() {
		float startSecond, endSecond = -1;
		try {
			startSecond = Float.valueOf(this.startSecondField.getText());
			endSecond = Float.valueOf(this.endSecondField.getText());
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Make sure that start and end second are floating point numbers", e, true);
			return;
		}
		
		try {
			this.job.setJobName(this.jobNameField.getText());
			this.job.setEnginePath(this.enginePathFC.getSelectedFile());
			this.job.setEngineParameters(this.engineParameterField.getText());
			this.job.setDemoFile(this.demoFileFC.getSelectedFile());
			this.job.setRelativeDemoPath(this.relativeDemoPathField.getText());
			this.job.setDpVideoPath(this.dpVideoDirFC.getSelectedFile());
			this.job.setVideoDestination(this.videoDestinationFC.getSelectedFile());
			this.job.setExecuteBeforeCap(this.execBeforeField.getText());
			this.job.setExecuteAfterCap(this.execAfterField.getText());
			this.job.setStartSecond(startSecond);
			this.job.setEndSecond(endSecond);
			this.saveEncoderPluginSettings(this.job);
			this.appLayer.fireUserInterfaceUpdate(this.job);
			dispose();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(e);
			return;
		}
		
	}
	
	private void createNewTemplate() {
		try {
			RecordJobTemplate templ = new RecordJobTemplate(
				this.templateNameField.getText(),
				this.templateSummaryField.getText(),
				this.jobNameField.getText(),
				this.enginePathFC.getSelectedFile(),
				this.engineParameterField.getText(),
				this.demoFileFC.getSelectedFile(),
				this.relativeDemoPathField.getText(),
				this.dpVideoDirFC.getSelectedFile(),
				this.videoDestinationFC.getSelectedFile(),
				this.execBeforeField.getText(),
				this.execAfterField.getText()
			);
			this.saveEncoderPluginSettings(templ);
			this.tableModel.addRecordJobTemplate(templ);
			dispose();
		} catch (NullPointerException e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Make sure that you chose a file/directory in each case!", e, true);
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(e);
			return;
		}
	}
	
	private void editTemplate() {
		try {
			RecordJobTemplate template = (RecordJobTemplate) this.job;
			template.setName(this.templateNameField.getText());
			template.setSummary(this.templateSummaryField.getText());
			template.setJobName(this.jobNameField.getText());
			template.setEnginePath(this.enginePathFC.getSelectedFile());
			template.setEngineParameters(this.engineParameterField.getText());
			template.setDpVideoPath(this.dpVideoDirFC.getSelectedFile());
			template.setRelativeDemoPath(this.relativeDemoPathField.getText());
			template.setDemoFile(this.demoFileFC.getSelectedFile());
			template.setExecuteBeforeCap(this.execBeforeField.getText());
			template.setExecuteAfterCap(this.execAfterField.getText());
			template.setVideoDestination(this.videoDestinationFC.getSelectedFile());
			this.saveEncoderPluginSettings(template);
			dispose();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(e);
			return;
		}
	}
	
	private void saveEncoderPluginSettings(RecordJob job) {
		Set<String> keys = this.pluginDialogSettings.keySet();
		//remember, the keys are concatenated, containing both the category and actual key 
		for (String key : keys) {
			JComponent component = this.pluginDialogSettings.get(key);
			if (component instanceof JCheckBox) {
				JCheckBox checkbox = (JCheckBox) component;
				job.setEncoderPluginSetting(NDRPreferences.getCategory(key), NDRPreferences.getKey(key), String.valueOf(checkbox.isSelected()));
			} else if (component instanceof JFileChooser) {
				JFileChooser fileChooser = (JFileChooser) component;
				if (fileChooser.getSelectedFile() != null) {
					String path = fileChooser.getSelectedFile().getAbsolutePath();
					job.setEncoderPluginSetting(NDRPreferences.getCategory(key), NDRPreferences.getKey(key), path);
				}
			} else if (component instanceof JTextField) {
				JTextField textField = (JTextField) component;
				job.setEncoderPluginSetting(NDRPreferences.getCategory(key), NDRPreferences.getKey(key), textField.getText());
			}
		}
	}
	
	private static class FileChooserButton extends JButton {
		private static final long serialVersionUID = 1335571540372856959L;
		public FileChooserButton() {
			super("...");
		}
	}
	
	private JFileChooser createConfiguredFileChooser() {
		JFileChooser fc = new JFileChooser();
		fc.setFileHidingEnabled(false);
		fc.setFileFilter(userDirFilter);
		return fc;
	}
}
