package com.nexuiz.demorecorder.ui.swinggui;

import java.awt.Frame;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.io.File;
import java.util.List;

import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JOptionPane;

import net.miginfocom.swing.MigLayout;

import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.application.jobs.RecordJob;

public class ApplyTemplateDialog extends JDialog implements ActionListener, ItemListener {

	private static final long serialVersionUID = 4807155579295688578L;
	private Frame parentFrame;
	private RecordJobTemplate template;
	private List<RecordJob> jobs;
	
	private JCheckBox engineCB = new JCheckBox("Engine", true);
	private JCheckBox engineParametersCB = new JCheckBox("Engine parameters", true);
	private JCheckBox dpVideoDirCB = new JCheckBox("DPVideo directory", true);
	private JCheckBox relativeDemoPathCB = new JCheckBox("Relative demo path", true);
	private JCheckBox jobNameCB = new JCheckBox("Job name", true);
	private JCheckBox demoDirectoryCB = new JCheckBox("Demo directory", true);
	private JCheckBox execBeforeCapCB = new JCheckBox("Exec before capture", true);
	private JCheckBox execAfterCB = new JCheckBox("Exec after capture", true);
	private JCheckBox videoDestination = new JCheckBox("Video destination", true);
	private JCheckBox pluginSettingsCB = new JCheckBox("Plug-in settings", true);
	private JCheckBox selectAllCB = new JCheckBox("Select/deselect all", true);
	
	private JButton applyButton = new JButton("Apply");
	private JButton cancelButton = new JButton("Cancel");
	
	public ApplyTemplateDialog(Frame owner, RecordJobTemplate template, List<RecordJob> jobs) {
		super(owner, true);
		this.parentFrame = owner;
		this.template = template;
		this.jobs = jobs;
		
		setDefaultCloseOperation(DISPOSE_ON_CLOSE);
		setTitle("Apply template");
		this.setupLayout();
	}
	
	public void showDialog() {
		this.pack();
		this.setLocationRelativeTo(this.parentFrame);
		this.setVisible(true);
	}

	private void setupLayout() {
		setLayout(new MigLayout());
		getContentPane().add(new JLabel("Select which properties you want to apply to the selected jobs"), "wrap");
		
		this.setupCheckBoxes();
		
		applyButton.addActionListener(this);
		cancelButton.addActionListener(this);
		getContentPane().add(applyButton);
		getContentPane().add(cancelButton);
	}
	
	private void setupCheckBoxes() {
		getContentPane().add(engineCB, "wrap");
		getContentPane().add(engineParametersCB, "wrap");
		getContentPane().add(dpVideoDirCB, "wrap");
		getContentPane().add(relativeDemoPathCB, "wrap");
		getContentPane().add(jobNameCB, "wrap");
		getContentPane().add(demoDirectoryCB, "wrap");
		getContentPane().add(execBeforeCapCB, "wrap");
		getContentPane().add(execAfterCB, "wrap");
		getContentPane().add(videoDestination, "wrap");
		getContentPane().add(pluginSettingsCB, "wrap");
		getContentPane().add(selectAllCB, "wrap");
		
		selectAllCB.addItemListener(this);
	}

	@Override
	public void actionPerformed(ActionEvent e) {
		if (e.getSource() == applyButton) {
			this.applyTemplates();
			dispose();
		} else if (e.getSource() == cancelButton) {
			dispose();
		}
	}
	
	private void applyTemplates() {
		String errors = "";
		for (RecordJob job : this.jobs) {
			try {
				this.applyTemplate(job);
			} catch (Throwable e) {
				errors += "Job <B>" + job.getJobName() + "</B>: " + e.getMessage() + "<BR>";
			}
		}
		
		if (!errors.equals("")) {
			//error occurred!
			String errorMsg = "<HTML><BODY>Error occurred while trying to apply templates:<BR><BR>" + errors + "</BODY></HTML>";
			JOptionPane.showMessageDialog(this.parentFrame, errorMsg, "Error(s) while applying template", JOptionPane.INFORMATION_MESSAGE);
		}
	}
	
	private void applyTemplate(RecordJob job) {
		if (engineCB.isSelected()) {
			job.setEnginePath(template.getEnginePath());
		}
		if (engineParametersCB.isSelected()) {
			job.setEngineParameters(template.getEngineParameters());
		}
		if (dpVideoDirCB.isSelected()) {
			job.setDpVideoPath(template.getDpVideoPath());
		}
		if (relativeDemoPathCB.isSelected()) {
			job.setRelativeDemoPath(template.getRelativeDemoPath());
		}
		if (jobNameCB.isSelected()) {
			job.setJobName(template.getJobName());
		}
		if (demoDirectoryCB.isSelected()) {
			File demoDir = template.getDemoFile();
			String demoFileName = DemoRecorderUtils.getJustFileNameOfPath(job.getDemoFile());
			String newDemoPath = demoDir.getAbsolutePath() + File.separator + demoFileName;
			job.setDemoFile(new File(newDemoPath));
		}
		if (execBeforeCapCB.isEnabled()) {
			job.setExecuteBeforeCap(template.getExecuteBeforeCap());
		}
		if (execAfterCB.isSelected()) {
			job.setExecuteAfterCap(template.getExecuteAfterCap());
		}
		if (videoDestination.isSelected()) {
			File videoDestinatinDir = template.getVideoDestination();
			String videoFileName = DemoRecorderUtils.getJustFileNameOfPath(job.getVideoDestination());
			String newVideoPath = videoDestinatinDir.getAbsolutePath() + File.separator + videoFileName;
			job.setVideoDestination(new File(newVideoPath));
		}
		if (pluginSettingsCB.isSelected()) {
			job.setEncoderPluginSettings(template.getEncoderPluginSettings());
		}
	}

	@Override
	public void itemStateChanged(ItemEvent e) {
		if (e.getSource() == selectAllCB) {
			boolean selected = false;
			if (e.getStateChange() == ItemEvent.SELECTED) {
				selected = true;
			}
			
			engineCB.setSelected(selected);
			engineParametersCB.setSelected(selected);
			dpVideoDirCB.setSelected(selected);
			relativeDemoPathCB.setSelected(selected);
			jobNameCB.setSelected(selected);
			demoDirectoryCB.setSelected(selected);
			execBeforeCapCB.setSelected(selected);
			execAfterCB.setSelected(selected);
			videoDestination.setSelected(selected);
			pluginSettingsCB.setSelected(selected);
		}
	}
}
