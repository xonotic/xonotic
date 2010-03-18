package com.nexuiz.demorecorder.ui.swinggui;

import java.awt.Container;
import java.awt.Dimension;
import java.awt.Point;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.awt.event.WindowEvent;
import java.awt.event.WindowListener;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

import javax.help.HelpBroker;
import javax.help.HelpSet;
import javax.swing.BorderFactory;
import javax.swing.Icon;
import javax.swing.ImageIcon;
import javax.swing.JButton;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.JMenu;
import javax.swing.JMenuBar;
import javax.swing.JMenuItem;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPopupMenu;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.UIManager;
import javax.swing.border.TitledBorder;

import net.miginfocom.swing.MigLayout;

import org.jdesktop.swingx.JXTable;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.application.NDRPreferences;
import com.nexuiz.demorecorder.application.DemoRecorderApplication.Preferences;
import com.nexuiz.demorecorder.application.jobs.RecordJob;
import com.nexuiz.demorecorder.application.jobs.RecordJob.State;
import com.nexuiz.demorecorder.application.plugins.EncoderPlugin;
import com.nexuiz.demorecorder.ui.DemoRecorderUI;
import com.nexuiz.demorecorder.ui.swinggui.tablemodels.RecordJobTemplatesTableModel;
import com.nexuiz.demorecorder.ui.swinggui.tablemodels.RecordJobsTableModel;
import com.nexuiz.demorecorder.ui.swinggui.utils.ShowErrorDialogExceptionHandler;
import com.nexuiz.demorecorder.ui.swinggui.utils.XProperties;
import com.nexuiz.demorecorder.ui.swinggui.utils.XProperties.XTableState;

public class SwingGUI extends JFrame implements WindowListener, DemoRecorderUI {
	
	private static final long serialVersionUID = -7287303462488231068L;
	public static final String JOB_TABLE_PREFERENCES_FILENAME = "jobsTable.pref";
	public static final String TEMPLATE_TABLE_PREFERENCES_FILENAME = "templatesTable.pref";
	public static final String TEMPLATE_TABLE_CONTENT_FILENAME = "templates.dat";

	private DemoRecorderApplication appLayer;
	private PreferencesDialog preferencesDialog;
	
	private JXTable jobsTable = null;
	private JPopupMenu jobsTablePopupMenu;
	private ActionListener jobButtonActionListener = new JobButtonActionListener();
	private MouseListener jobsTableMouseListener = new JobsTableMouseListener();
	
	private JXTable templatesTable = null;
	private JPopupMenu templatesTablePopupMenu;
	private ActionListener templateButtonActionListener = new TemplateButtonActionListener();
	private MouseListener templatesTableMouseListener = new TemplatesTableMouseListener();
	
	private ActionListener recordButtonActionListener = new RecordButtonActionListener();
	
	private static final String LABEL_JOB_CREATE = "Create";
	private static final String LABEL_JOB_CREATE_FROM_TEMPL = "Create from template";
	private static final String LABEL_JOB_DELETE = "Delete";
	private static final String LABEL_JOB_CLEAR = "Clear";
	private static final String LABEL_JOB_EDIT = "Edit job";
	private static final String LABEL_JOB_DUPLICATE = "Duplicate job";
	private static final String LABEL_JOB_APPLYTEMPL = "Apply template";
	private static final String LABEL_JOB_START = "Start job";
	private static final String LABEL_JOB_SHOWERROR = "Show error message";
	private static final String LABEL_JOB_RESET_STATE_WAITING = "Reset job status to 'waiting'";
	private static final String LABEL_JOB_RESET_STATE_DONE = "Reset job status to 'done'";
	
	private static final String LABEL_TEMPL_CREATE = "Create";
	private static final String LABEL_TEMPL_CREATE_FROM_JOB = "Create from job";
	private static final String LABEL_TEMPL_DELETE = "Delete";
	private static final String LABEL_TEMPL_CLEAR = "Clear";
	private static final String LABEL_TEMPL_EDIT = "Edit template";
	private static final String LABEL_TEMPL_DUPLICATE = "Duplicate template";
	
	private ActionListener menuButtonActionListener = new MenuButtonActionListener();
	private JMenuItem fileLoadQueue = new JMenuItem("Load job queue", getIcon("fileopen.png"));
	private JMenuItem fileSaveQueue = new JMenuItem("Save job queue", getIcon("filesave.png"));
	private JMenuItem fileLoadTemplates = new JMenuItem("Load templates", getIcon("fileopen.png"));
	private JMenuItem fileSaveTemplates = new JMenuItem("Save templates", getIcon("filesave.png"));
	private JMenuItem filePreferences = new JMenuItem("Preferences", getIcon("advanced.png"));
	private JMenuItem fileExit = new JMenuItem("Exit", getIcon("exit.png"));
	private JMenuItem helpHelp = new JMenuItem("Show help", getIcon("help.png"));
	private JMenuItem helpAbout = new JMenuItem("About", getIcon("info.png"));
	private JFileChooser jobQueueSaveAsFC = new JFileChooser();
	private JFileChooser templatesSaveAsFC = new JFileChooser();
	
	private JButton jobs_create = new JButton(LABEL_JOB_CREATE, getIcon("edit_add.png"));
	private JButton jobs_createFromTempl = new JButton(LABEL_JOB_CREATE_FROM_TEMPL, getIcon("view_right_p.png"));
	private JButton jobs_delete = new JButton(LABEL_JOB_DELETE, getIcon("editdelete.png"));
	private JButton jobs_clear = new JButton(LABEL_JOB_CLEAR, getIcon("editclear.png"));
	private JMenuItem jobs_contextmenu_edit = new JMenuItem(LABEL_JOB_EDIT, getIcon("edit.png"));
	private JMenuItem jobs_contextmenu_duplicate = new JMenuItem(LABEL_JOB_DUPLICATE, getIcon("editcopy.png"));
	private JMenuItem jobs_contextmenu_applytempl = new JMenuItem(LABEL_JOB_APPLYTEMPL, getIcon("editpaste.png"));
	private JMenuItem jobs_contextmenu_delete = new JMenuItem(LABEL_JOB_DELETE, getIcon("editdelete.png"));
	private JMenuItem jobs_contextmenu_start = new JMenuItem(LABEL_JOB_START, getIcon("player_play.png"));
	private JMenuItem jobs_contextmenu_showerror = new JMenuItem(LABEL_JOB_SHOWERROR, getIcon("status_unknown.png"));
	private JMenuItem jobs_contextmenu_resetstate_waiting = new JMenuItem(LABEL_JOB_RESET_STATE_WAITING, getIcon("quick_restart.png"));
	private JMenuItem jobs_contextmenu_resetstate_done = new JMenuItem(LABEL_JOB_RESET_STATE_DONE, getIcon("quick_restart_blue.png"));
	private List<JMenuItem> jobs_contextmenu_runPluginMenuItems = new ArrayList<JMenuItem>();
	
	private JButton templ_create = new JButton(LABEL_TEMPL_CREATE, getIcon("edit_add.png"));
	private JButton templ_createFromJob = new JButton(LABEL_TEMPL_CREATE_FROM_JOB, getIcon("view_right_p.png"));
	private JButton templ_delete = new JButton(LABEL_TEMPL_DELETE, getIcon("editdelete.png"));
	private JButton templ_clear = new JButton(LABEL_TEMPL_CLEAR, getIcon("editclear.png"));
	private JMenuItem templ_contextmenu_edit = new JMenuItem(LABEL_TEMPL_EDIT, getIcon("edit.png"));
	private JMenuItem templ_contextmenu_duplicate = new JMenuItem(LABEL_TEMPL_DUPLICATE, getIcon("editcopy.png"));
	private JMenuItem templ_contextmenu_delete = new JMenuItem(LABEL_TEMPL_DELETE, getIcon("editdelete.png"));
	
	private static final String PROCESSING_START = "Start processing";
	private static final String PROCESSING_STOP_NOW = "Stop processing";
	private static final String PROCESSING_STOP_LATER = "Processing will stop after current job finished";
	private JButton processing_start = new JButton(PROCESSING_START, getIcon("player_play.png"));
	private JButton processing_stop = new JButton(PROCESSING_STOP_NOW, getIcon("player_pause.png"));
	
	private StatusBar statusBar = new StatusBar();
	
	private static HelpBroker mainHelpBroker = null;
	private static final String mainHelpSetName = "help/DemoRecorderHelp.hs";

	public SwingGUI(DemoRecorderApplication appLayer) {
		super("Nexuiz Demo Recorder v0.3");
		addWindowListener(this);

		this.appLayer = appLayer;

		this.setupLayout();
		this.setupHelp();
		this.preferencesDialog = new PreferencesDialog(this, appLayer);

		setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
		// Display the window.
		pack();
		setVisible(true);
		//now that we have the GUI we can set the parent window for the error dialog
		ShowErrorDialogExceptionHandler.setParentWindow(this);
	}

	private void setupHelp() {
		if (mainHelpBroker == null){
			HelpSet mainHelpSet = null;

			try {
				URL hsURL = HelpSet.findHelpSet(null, mainHelpSetName);
				mainHelpSet = new HelpSet(null, hsURL);
			} catch (Exception e) {
				DemoRecorderUtils.showNonCriticalErrorDialog("Could not properly create the help", e, true);
			}

			if (mainHelpSet != null)
				mainHelpBroker = mainHelpSet.createHelpBroker();
			}
	}

	private void setupLayout() {
		setLayout(new MigLayout("wrap 1,insets 10", "[400:700:,grow,fill]",
				"[grow,fill][grow,fill][][]"));
		Container contentPane = getContentPane();
		setJMenuBar(this.buildMenu());

		this.setupTemplatePanel();
		this.setupJobPanel();
		this.setupRecordPanel();

		contentPane.add(statusBar, "south,height 23::");
	}

	private void setupTemplatePanel() {
		JPanel templatePanel = new JPanel(new MigLayout("", "[500:500:,grow,fill][170!,fill,grow]", "[grow,fill]"));
		TitledBorder templatePanelTitle = BorderFactory.createTitledBorder("Templates");
		templatePanel.setBorder(templatePanelTitle);
		getContentPane().add(templatePanel);
		
		this.setupTemplatesTable();
		this.loadTableStates(this.templatesTable);
		JScrollPane templateScrollPane = new JScrollPane(templatesTable);
		templatePanel.add(templateScrollPane);
		
		this.templ_create.addActionListener(this.templateButtonActionListener);
		this.templ_createFromJob.addActionListener(this.templateButtonActionListener);
		this.templ_delete.addActionListener(this.templateButtonActionListener);
		this.templ_clear.addActionListener(this.templateButtonActionListener);
		
		this.templ_contextmenu_edit.addActionListener(this.templateButtonActionListener);
		this.templ_contextmenu_duplicate.addActionListener(this.templateButtonActionListener);
		this.templ_contextmenu_delete.addActionListener(this.templateButtonActionListener);
		
		this.configureTableButtons();
		
		JPanel templateControlButtonPanel = new JPanel(new MigLayout("wrap 1", "fill,grow"));
		templateControlButtonPanel.add(this.templ_create);
		templateControlButtonPanel.add(this.templ_createFromJob);
		templateControlButtonPanel.add(this.templ_delete);
		templateControlButtonPanel.add(this.templ_clear);
		templatePanel.add(templateControlButtonPanel);
	}

	private void setupJobPanel() {
		JPanel jobPanel = new JPanel(new MigLayout("", "[500:500:,grow,fill][170!,fill,grow]", "[grow,fill]"));
		TitledBorder jobPanelTitle = BorderFactory.createTitledBorder("Jobs");
		jobPanel.setBorder(jobPanelTitle);
		getContentPane().add(jobPanel);

		this.setupJobsTable();
		this.loadTableStates(this.jobsTable);
		
		JScrollPane jobScrollPane = new JScrollPane(jobsTable);
		jobPanel.add(jobScrollPane);
		
		this.jobs_create.addActionListener(this.jobButtonActionListener);
		this.jobs_createFromTempl.addActionListener(this.jobButtonActionListener);
		this.jobs_delete.addActionListener(this.jobButtonActionListener);
		this.jobs_clear.addActionListener(this.jobButtonActionListener);
		
		this.jobs_contextmenu_edit.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_duplicate.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_applytempl.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_delete.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_start.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_showerror.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_resetstate_waiting.addActionListener(this.jobButtonActionListener);
		this.jobs_contextmenu_resetstate_done.addActionListener(this.jobButtonActionListener);
		
		//initialize button states
		configureTableButtons();
		
		JPanel jobControlButtonPanel = new JPanel(new MigLayout("wrap 1", "fill,grow"));
		jobControlButtonPanel.add(this.jobs_create);
		jobControlButtonPanel.add(this.jobs_createFromTempl);
		jobControlButtonPanel.add(this.jobs_delete);
		jobControlButtonPanel.add(this.jobs_clear);
		jobPanel.add(jobControlButtonPanel);
	}
	
	private void setupJobsTable() {
		RecordJobsTableModel tableModel = new RecordJobsTableModel(this.appLayer);
		jobsTable = new JXTable(tableModel);
		jobsTable.setColumnControlVisible(true);
		jobsTable.setPreferredScrollableViewportSize(new Dimension(400, 100));
		jobsTable.addMouseListener(this.jobsTableMouseListener);
	}
	
	private void setupTemplatesTable() {
		RecordJobTemplatesTableModel tableModel = new RecordJobTemplatesTableModel();
		templatesTable = new JXTable(tableModel);
		templatesTable.setColumnControlVisible(true);
		templatesTable.setPreferredScrollableViewportSize(new Dimension(400, 100));
		templatesTable.addMouseListener(this.templatesTableMouseListener);
	}

	private void setupRecordPanel() {
		JPanel recButtonPanel = new JPanel(new MigLayout());
		recButtonPanel.add(processing_start);
		recButtonPanel.add(processing_stop);
		processing_stop.setEnabled(false);
		processing_start.addActionListener(recordButtonActionListener);
		processing_stop.addActionListener(recordButtonActionListener);
		getContentPane().add(recButtonPanel);
	}

	public static void setSystemLAF() {
		try {
			// Set System L&F
			UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
		} catch (Exception e) {
		}
	}
	
	public void RecordJobPropertiesChange(RecordJob job) {
		RecordJobsTableModel jobsTableModel = (RecordJobsTableModel) this.jobsTable.getModel();
		List<RecordJob> recordJobs = jobsTableModel.getRecordJobs();
		int jobIndex = recordJobs.indexOf(job);
		if (jobIndex == -1) {
			//new job
			recordJobs.add(job);
			//add job at the end of the table:
			int position = jobsTableModel.getRowCount() - 1;
			jobsTableModel.fireTableRowsInserted(position, position);
		} else {
			//job already existed
			jobIndex = this.jobsTable.convertRowIndexToView(jobIndex); //convert due to possible view sorting
			jobsTableModel.fireTableRowsUpdated(jobIndex, jobIndex);
		}
	}

	public void recordingFinished() {
		JOptionPane.showMessageDialog(SwingGUI.this, "Finished recording all jobs", "Recording done", JOptionPane.INFORMATION_MESSAGE);
		statusBar.showState(false);
		processing_start.setEnabled(true);
		processing_stop.setEnabled(false);
		processing_stop.setText(PROCESSING_STOP_NOW);
	}

	private JMenuBar buildMenu() {
		JMenuBar menuBar = new JMenuBar();

		JMenu fileMenu = new JMenu("File");
		fileMenu.add(fileLoadQueue);
		fileMenu.add(fileSaveQueue);
		fileMenu.add(fileLoadTemplates);
		fileMenu.add(fileSaveTemplates);
		fileMenu.add(filePreferences);
		fileMenu.add(fileExit);
		menuBar.add(fileMenu);
		
		fileLoadQueue.addActionListener(menuButtonActionListener);
		fileSaveQueue.addActionListener(menuButtonActionListener);
		fileLoadTemplates.addActionListener(menuButtonActionListener);
		fileSaveTemplates.addActionListener(menuButtonActionListener);
		filePreferences.addActionListener(menuButtonActionListener);
		fileExit.addActionListener(menuButtonActionListener);

		JMenu helpMenu = new JMenu("Help");
		helpMenu.add(helpHelp);
		helpMenu.add(helpAbout);
		menuBar.add(helpMenu);
		
		helpHelp.addActionListener(menuButtonActionListener);
		helpAbout.addActionListener(menuButtonActionListener);
		
		this.setupEncoderPluginButtons();
		
		this.jobsTablePopupMenu = new JPopupMenu();
		this.jobsTablePopupMenu.add(jobs_contextmenu_edit);
		this.jobsTablePopupMenu.add(jobs_contextmenu_duplicate);
		this.jobsTablePopupMenu.add(jobs_contextmenu_applytempl);
		this.jobsTablePopupMenu.add(jobs_contextmenu_delete);
		this.jobsTablePopupMenu.add(jobs_contextmenu_start);
		//add JMenus for plugins
		for (JMenuItem menuItem : jobs_contextmenu_runPluginMenuItems) {
			this.jobsTablePopupMenu.add(menuItem);
		}
		this.jobsTablePopupMenu.add(jobs_contextmenu_showerror);
		this.jobsTablePopupMenu.add(jobs_contextmenu_resetstate_waiting);
		this.jobsTablePopupMenu.add(jobs_contextmenu_resetstate_done);
		
		
		
		
		this.templatesTablePopupMenu = new JPopupMenu();
		this.templatesTablePopupMenu.add(templ_contextmenu_edit);
		this.templatesTablePopupMenu.add(templ_contextmenu_duplicate);
		this.templatesTablePopupMenu.add(templ_contextmenu_delete);

		return menuBar;
	}
	
	private void setupEncoderPluginButtons() {
		for (EncoderPlugin plugin : appLayer.getEncoderPlugins()) {
			JMenuItem pluginMenuItem = new JMenuItem("Just run " + plugin.getName() + " plugin", getIcon("package.png"));
			pluginMenuItem.addActionListener(jobButtonActionListener);
			this.jobs_contextmenu_runPluginMenuItems.add(pluginMenuItem);
		}
	}

	private void saveTableStates(JXTable table) {
		String fileName;
		if (table == jobsTable) {
			fileName = JOB_TABLE_PREFERENCES_FILENAME;
		} else {
			fileName = TEMPLATE_TABLE_PREFERENCES_FILENAME;
		}
		String exceptionMessage = "An error occurred while trying to save the table state file " + fileName;
		
		XProperties.XTableProperty t = new XProperties.XTableProperty();
		XTableState tableState;
		try {
			tableState = (XTableState) t.getSessionState(table);
		} catch (Exception e) { //most likely ClassCastException
			DemoRecorderUtils.showNonCriticalErrorDialog(exceptionMessage, e, true);
			return;
		}
		
		File tableStateFile = DemoRecorderUtils.computeLocalFile(DemoRecorderApplication.PREFERENCES_DIRNAME, fileName);
		DemoRecorderUtils.attemptFileCreation(tableStateFile);
		
		try {
			FileOutputStream fout = new FileOutputStream(tableStateFile);
			ObjectOutputStream oos = new ObjectOutputStream(fout);
			oos.writeObject(tableState);
			oos.close();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(exceptionMessage, e, true);
		}
	}
	
	private void loadTableStates(JXTable table) {
		String fileName;
		if (table == jobsTable) {
			fileName = JOB_TABLE_PREFERENCES_FILENAME;
		} else {
			fileName = TEMPLATE_TABLE_PREFERENCES_FILENAME;
		}
		
		XProperties.XTableProperty t = new XProperties.XTableProperty();
		
		File tableStateFile = DemoRecorderUtils.computeLocalFile(DemoRecorderApplication.PREFERENCES_DIRNAME, fileName);
		
		XTableState tableState;
		
		try {
			FileInputStream fin = new FileInputStream(tableStateFile);
			ObjectInputStream ois = new ObjectInputStream(fin);
			tableState = (XTableState) ois.readObject();
			t.setSessionState(table, tableState);
		} catch (Exception e) {
			 //manually hide columns
			if (table == jobsTable) {
				//re-create table to be sure
				this.setupJobsTable();
				//manually hide some columns
				jobsTable.getColumnExt(RecordJobsTableModel.EXECUTE_AFTER_CAP).setVisible(false);
				jobsTable.getColumnExt(RecordJobsTableModel.EXECUTE_BEFORE_CAP).setVisible(false);
				jobsTable.getColumnExt(RecordJobsTableModel.VIDEO_DESTINATION_PATH).setVisible(false);
				jobsTable.getColumnExt(RecordJobsTableModel.DPVIDEO_PATH).setVisible(false);
				jobsTable.getColumnExt(RecordJobsTableModel.RELATIVE_DEMO_PATH).setVisible(false);
				jobsTable.getColumnExt(RecordJobsTableModel.ENGINE_PARAMETERS).setVisible(false);
				jobsTable.getColumnExt(RecordJobsTableModel.ENGINE_PATH).setVisible(false);
			} else {
				//re-create table to be sure
				this.setupTemplatesTable();
				//manually hide some columns
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.EXECUTE_AFTER_CAP).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.EXECUTE_BEFORE_CAP).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.VIDEO_DESTINATION_PATH).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.DPVIDEO_PATH).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.RELATIVE_DEMO_PATH).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.DEMO_FILE_PATH).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.ENGINE_PARAMETERS).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.ENGINE_PATH).setVisible(false);
				templatesTable.getColumnExt(RecordJobTemplatesTableModel.JOB_NAME).setVisible(false);
			}
		}
	}
	
	private class MenuButtonActionListener implements ActionListener {

		public void actionPerformed(ActionEvent e) {
			if (e.getSource() == fileLoadQueue) {
				int result = jobQueueSaveAsFC.showOpenDialog(SwingGUI.this);
				if (result == JFileChooser.APPROVE_OPTION) {
					File selectedFile = jobQueueSaveAsFC.getSelectedFile();
					if (selectedFile.isFile()) {
						RecordJobsTableModel tableModel = (RecordJobsTableModel) jobsTable.getModel();
						tableModel.loadNewJobQueue(SwingGUI.this, selectedFile, jobsTable);
						configureTableButtons();
					}
				}
				
			} else if (e.getSource() == fileSaveQueue) {
				int result = jobQueueSaveAsFC.showSaveDialog(SwingGUI.this);
				if (result == JFileChooser.APPROVE_OPTION) {
					File selectedFile = jobQueueSaveAsFC.getSelectedFile();
					if (!DemoRecorderUtils.getFileExtension(selectedFile).equals("queue")) {
						//if file is not a .queue file, make it one
						selectedFile = new File(selectedFile.getAbsoluteFile() + ".queue");
					}
					if (selectedFile.exists()) {
						int confirm = JOptionPane.showConfirmDialog(SwingGUI.this, "File already exists. Are you sure you want to overwrite it?", "Confirm overwrite", JOptionPane.YES_NO_OPTION);
						if (confirm == JOptionPane.NO_OPTION) {
							return;
						}
					}
					appLayer.saveJobQueue(selectedFile);
				}
			} else if (e.getSource() == fileLoadTemplates) {
				int result = templatesSaveAsFC.showOpenDialog(SwingGUI.this);
				if (result == JFileChooser.APPROVE_OPTION) {
					File selectedFile = templatesSaveAsFC.getSelectedFile();
					if (selectedFile.isFile()) {
						RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) templatesTable.getModel();
						tableModel.loadNewTemplateList(SwingGUI.this, selectedFile, templatesTable);
						configureTableButtons();
					}
				}
			} else if (e.getSource() == fileSaveTemplates) {
				int result = templatesSaveAsFC.showSaveDialog(SwingGUI.this);
				if (result == JFileChooser.APPROVE_OPTION) {
					File selectedFile = templatesSaveAsFC.getSelectedFile();
					if (!DemoRecorderUtils.getFileExtension(selectedFile).equals("templ")) {
						selectedFile = new File(selectedFile.getAbsoluteFile() + ".templ");
					}
					if (selectedFile.exists()) {
						int confirm = JOptionPane.showConfirmDialog(SwingGUI.this, "File already exists. Are you sure you want to overwrite it?", "Confirm overwrite", JOptionPane.YES_NO_OPTION);
						if (confirm == JOptionPane.NO_OPTION) {
							return;
						}
					}
					RecordJobTemplatesTableModel model = (RecordJobTemplatesTableModel) templatesTable.getModel();
					model.saveTemplateListToFile(selectedFile);
				}
			} else if (e.getSource() == filePreferences) {
				preferencesDialog.showDialog();
			} else if (e.getSource() == fileExit) {
				shutDown();
			} else if (e.getSource() == helpHelp) {
				if (mainHelpBroker != null) {
					mainHelpBroker.setDisplayed(true);
				}
			} else if (e.getSource() == helpAbout) {
				showAboutBox();
			}
		}
		
	}

	/**
	 * Listens to the clicks on buttons that are in the job panel (next to the jobs table)
	 * or its context menu.
	 */
	private class JobButtonActionListener implements ActionListener {

		public void actionPerformed(ActionEvent e) {
			List<RecordJob> selectedJobs = getSelectedRecordJobs(jobsTable);
			List<RecordJob> selectedTemplates = getSelectedRecordJobs(templatesTable);
			if (e.getSource() == jobs_create) {
				JobDialog jobDialog = new JobDialog(SwingGUI.this, appLayer);
				jobDialog.showDialog();
				configureTableButtons();
			}
			else if (e.getSource() == jobs_createFromTempl) {
				if (selectedTemplates.size() != 1) {
					return;
				}
				RecordJobTemplate template = (RecordJobTemplate) selectedTemplates.get(0);
//				JobDialog jobDialog = new JobDialog(SwingGUI.this, template, appLayer);
				JobDialog jobDialog = new JobDialog(SwingGUI.this, template, appLayer, JobDialog.CREATE_JOB_FROM_TEMPLATE);
				jobDialog.showDialog();
				configureTableButtons();
			}
			else if (e.getSource() == jobs_delete || e.getSource() == jobs_contextmenu_delete) {
				int result = JOptionPane.showConfirmDialog(SwingGUI.this, "Are you sure you want to delete the selected job(s)?", "Confirm delete", JOptionPane.YES_NO_OPTION);
				if (result == JOptionPane.YES_OPTION) {
					deleteSelectedJobs(false);
					configureTableButtons();
				}
			}
			else if (e.getSource() == jobs_clear) {
				int result = JOptionPane.showConfirmDialog(SwingGUI.this, "Are you sure you want to clear the job list?", "Confirm clear", JOptionPane.YES_NO_OPTION);
				if (result == JOptionPane.YES_OPTION) {
					deleteSelectedJobs(true);
					configureTableButtons();
				}
			} else if (e.getSource() == jobs_contextmenu_edit) {
				if (selectedJobs.size() == 1) {
					RecordJob selectedJob = selectedJobs.get(0);
					JobDialog jobDialog = new JobDialog(SwingGUI.this, selectedJob, appLayer);
					jobDialog.showDialog();
					configureTableButtons();
				}
			} else if (e.getSource() == jobs_contextmenu_showerror) {
				if (selectedJobs.size() == 1) {
					RecordJob selectedJob = selectedJobs.get(0);
					DemoRecorderUtils.showNonCriticalErrorDialog(selectedJob.getLastException());
				}
			} else if (e.getSource() == jobs_contextmenu_resetstate_waiting) {
				for (RecordJob job : selectedJobs) {
					job.setState(RecordJob.State.WAITING);
				}
			} else if (e.getSource() == jobs_contextmenu_resetstate_done) {
				for (RecordJob job : selectedJobs) {
					if (job.getState() == State.ERROR_PLUGIN) {
						job.setState(RecordJob.State.DONE);
					}
				}
			} else if (e.getSource() == jobs_contextmenu_start) {
				appLayer.recordSelectedJobs(selectedJobs);
				if (appLayer.getState() == DemoRecorderApplication.STATE_WORKING) {
					processing_start.setEnabled(false);
					processing_stop.setEnabled(true);
					statusBar.showState(true);
				}
			} else if (e.getSource() == jobs_contextmenu_duplicate) {
				if (selectedJobs.size() > 0) {
					this.duplicateRecordJobs(selectedJobs);
					//select all new duplicates in the table automatically
					jobsTable.setRowSelectionInterval(jobsTable.getRowCount() - selectedJobs.size(), jobsTable.getRowCount() - 1);
					configureTableButtons();
				}
			} else if (e.getSource() == jobs_contextmenu_applytempl) {
				if (selectedTemplates.size() == 1 && selectedJobs.size() > 0) {
					RecordJobTemplate template = (RecordJobTemplate) selectedTemplates.get(0);
					ApplyTemplateDialog applyDialog = new ApplyTemplateDialog(SwingGUI.this, template, selectedJobs);
					applyDialog.showDialog();
				}
			} else if (jobs_contextmenu_runPluginMenuItems.contains(e.getSource())) {
				int index = jobs_contextmenu_runPluginMenuItems.indexOf(e.getSource());
				EncoderPlugin selectedPlugin = appLayer.getEncoderPlugins().get(index);
				
				appLayer.executePluginForSelectedJobs(selectedPlugin, selectedJobs);
				if (appLayer.getState() == DemoRecorderApplication.STATE_WORKING) {
					processing_start.setEnabled(false);
					processing_stop.setEnabled(true);
					statusBar.showState(true);
				}
			}
		}
		
		private void duplicateRecordJobs(List<RecordJob> jobs) {
			String nameSuffix = appLayer.getPreferences().getProperty(NDRPreferences.MAIN_APPLICATION, Preferences.JOB_NAME_APPEND_DUPLICATE);
			for (RecordJob job : jobs) {
				RecordJob newJob = appLayer.createRecordJob(
					job.getJobName() + nameSuffix,
					job.getEnginePath(),
					job.getEngineParameters(),
					job.getDemoFile(),
					job.getRelativeDemoPath(),
					job.getDpVideoPath(),
					job.getVideoDestination(),
					job.getExecuteBeforeCap(),
					job.getExecuteAfterCap(),
					job.getStartSecond(),
					job.getEndSecond()
				);
				newJob.setEncoderPluginSettings(job.getEncoderPluginSettings());
			}
		}
		
	}
	
	private class TemplateButtonActionListener implements ActionListener {
		public void actionPerformed(ActionEvent e) {
			if (e.getSource() == templ_create) {
				RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) templatesTable.getModel();
				JobDialog jobDialog = new JobDialog(SwingGUI.this, tableModel, templatesTable, appLayer);
				jobDialog.showDialog();
				configureTableButtons();
			}
			else if (e.getSource() == templ_createFromJob) {
				this.createTemplateFromJob();
				configureTableButtons();
			}
			else if (e.getSource() == templ_delete || e.getSource() == templ_contextmenu_delete) {
				int result = JOptionPane.showConfirmDialog(SwingGUI.this, "Are you sure you want to delete the selected template(s)?", "Confirm delete", JOptionPane.YES_NO_OPTION);
				if (result == JOptionPane.YES_OPTION) {
					deleteSelectedTemplates(false);
				}
				configureTableButtons();
			}
			else if (e.getSource() == templ_clear) {
				int result = JOptionPane.showConfirmDialog(SwingGUI.this, "Are you sure you want to clear the template list?", "Confirm clear", JOptionPane.YES_NO_OPTION);
				if (result == JOptionPane.YES_OPTION) {
					deleteSelectedTemplates(true);
				}
				configureTableButtons();
			}
			else if (e.getSource() == templ_contextmenu_edit) {
				List<RecordJob> selectedTemplates = getSelectedRecordJobs(templatesTable);
				if (selectedTemplates.size() == 1) {
					RecordJobTemplate selectedTemplate = (RecordJobTemplate) selectedTemplates.get(0);
					JobDialog jobDialog = new JobDialog(SwingGUI.this, selectedTemplate, appLayer, JobDialog.EDIT_TEMPLATE);
					jobDialog.showDialog();
					configureTableButtons();
				}
			}
			else if (e.getSource() == templ_contextmenu_duplicate) {
				List<RecordJob> selectedTemplates = getSelectedRecordJobs(templatesTable);
				if (selectedTemplates.size() > 0) {
					this.duplicateTemplates(selectedTemplates);
					//select all new duplicates in the table automatically
					templatesTable.setRowSelectionInterval(templatesTable.getRowCount() - selectedTemplates.size(), templatesTable.getRowCount() - 1);
					configureTableButtons();
				}
			}
		}
		
		private void createTemplateFromJob() {
			List<RecordJob> selectedJobs = getSelectedRecordJobs(jobsTable);
			if (selectedJobs.size() == 1) {
				RecordJob job = selectedJobs.get(0);
				RecordJobTemplate templ = new RecordJobTemplate(
					"Generated from job",
					"Generated from job",
					job.getJobName(),
					job.getEnginePath(),
					job.getEngineParameters(),
					job.getDemoFile().getParentFile(),
					job.getRelativeDemoPath(),
					job.getDpVideoPath(),
					job.getVideoDestination().getParentFile(),
					job.getExecuteBeforeCap(),
					job.getExecuteAfterCap()
				);
				templ.setEncoderPluginSettings(job.getEncoderPluginSettings());
				
				RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) templatesTable.getModel();
				tableModel.addRecordJobTemplate(templ);
			}
		}
		
		private void duplicateTemplates(List<RecordJob> selectedTemplates) {
			for (RecordJob job : selectedTemplates) {
				RecordJobTemplate template = (RecordJobTemplate) job;
				RecordJobTemplate templ = new RecordJobTemplate(
					template.getName(),
					template.getSummary(),
					template.getJobName(),
					template.getEnginePath(),
					template.getEngineParameters(),
					template.getDemoFile(),
					template.getRelativeDemoPath(),
					template.getDpVideoPath(),
					template.getVideoDestination(),
					template.getExecuteBeforeCap(),
					template.getExecuteAfterCap()
				);
				templ.setEncoderPluginSettings(template.getEncoderPluginSettings());
				
				RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) templatesTable.getModel();
				tableModel.addRecordJobTemplate(templ);
			}
		}
	}
	
	private class RecordButtonActionListener implements ActionListener {

		public void actionPerformed(ActionEvent e) {
			if (e.getSource() == processing_start) {
				appLayer.startRecording();
				if (appLayer.getState() == DemoRecorderApplication.STATE_WORKING) {
					processing_start.setEnabled(false);
					processing_stop.setEnabled(true);
					statusBar.showState(true);
				}
			} else if (e.getSource() == processing_stop) {
				if (appLayer.getState() == DemoRecorderApplication.STATE_WORKING) {
					appLayer.stopRecording();
					processing_stop.setEnabled(false);
					processing_stop.setText(PROCESSING_STOP_LATER);
				}
			}
		}
	}
	
	private void deleteSelectedJobs(boolean deleteAllJobs) {
		RecordJobsTableModel tableModel = (RecordJobsTableModel) jobsTable.getModel();
		if (deleteAllJobs) {
			int rowCount = jobsTable.getRowCount();
			for (int i = rowCount - 1; i >= 0; i--) {
				int modelRowIndex = jobsTable.convertRowIndexToModel(i);
				tableModel.deleteRecordJob(modelRowIndex, i);
			}
		} else {
			int[] selectedRows = jobsTable.getSelectedRows();
			for (int i = selectedRows.length - 1; i >= 0; i--) {
				int modelRowIndex = jobsTable.convertRowIndexToModel(selectedRows[i]);
				tableModel.deleteRecordJob(modelRowIndex, selectedRows[i]);
			}
		}
	}
	
	private void deleteSelectedTemplates(boolean deleteAllTemplates) {
		RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) templatesTable.getModel();
		if (deleteAllTemplates) {
			int rowCount = templatesTable.getRowCount();
			for (int i = rowCount - 1; i >= 0; i--) {
				int modelRowIndex = templatesTable.convertRowIndexToModel(i);
				tableModel.deleteRecordJobTemplate(modelRowIndex, i);
			}
		} else {
			int[] selectedRows = templatesTable.getSelectedRows();
			for (int i = selectedRows.length - 1; i >= 0; i--) {
				int modelRowIndex = templatesTable.convertRowIndexToModel(selectedRows[i]);
				tableModel.deleteRecordJobTemplate(modelRowIndex, selectedRows[i]);
			}
		}
		//update the button state of buttons dealing with jobs
		this.configureTableButtons();
	}
	
	/**
	 * Iterates through all RecordJob objects (or just the selected ones) and returns true
	 * if at least one of them has one or more has the given state(s).
	 * @param state
	 * @param justSelectedJobs
	 * @return
	 */
	private boolean checkJobStates(RecordJob.State[] state, boolean justSelectedJobs) {
		boolean foundState = false;
		List<RecordJob> jobsToLookAt = null;
		if (!justSelectedJobs) {
			jobsToLookAt = this.appLayer.getRecordJobs();
		} else {
			jobsToLookAt = getSelectedRecordJobs(jobsTable);
		}
		
		for (RecordJob currentJob : jobsToLookAt) {
			for (int i = 0; i < state.length; i++) {
				if (currentJob.getState() == state[i]) {
					foundState = true;
					break;
				}
			}
		}
		return foundState;
	}
	
	/**
	 * Returns the list of selected RecordJobs or RecordJobTemplates.
	 * @param table jobsTable or templatesTable
	 * @return list of selected RecordJobs or RecordJobTemplates
	 */
	private List<RecordJob> getSelectedRecordJobs(JXTable table) {
		List<RecordJob> list = new ArrayList<RecordJob>();
		if (table.getSelectedRowCount() > 0) {
			int[] selectedRows = table.getSelectedRows();
			for (int i = 0; i < selectedRows.length; i++) {
				int modelRowIndex = table.convertRowIndexToModel(selectedRows[i]);
				if (table == jobsTable) {
					RecordJobsTableModel tableModel = (RecordJobsTableModel) table.getModel();
					RecordJob job = tableModel.getRecordJob(modelRowIndex);
					if (job != null) {
						list.add(job);
					}
				} else {
					RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) table.getModel();
					RecordJobTemplate template = tableModel.getRecordJobTemplate(modelRowIndex);
					if (template != null) {
						list.add(template);
					}
				}
			}
		}
		
		return list;
	}
	
	private void configureTableButtons() {
		if (jobsTable != null) {
			if (jobsTable.getRowCount() == 0) {
				jobs_clear.setEnabled(false);
				jobs_delete.setEnabled(false);
			} else {
				jobs_clear.setEnabled(true);
				jobs_delete.setEnabled(true);
				if (jobsTable.getSelectedRowCount() == 0) {
					jobs_delete.setEnabled(false);
				} else {
					//go through all elements and check for attributes PROCESSING
					RecordJob.State[] lookForState = {RecordJob.State.PROCESSING};
					boolean foundState = checkJobStates(lookForState, false);
					if (foundState) {
						//we have to disable the clear and delete button
						jobs_delete.setEnabled(false);
					}
				}
			}
			if (templatesTable.getSelectedRowCount() == 1) {
				jobs_createFromTempl.setEnabled(true);
			} else {
				jobs_createFromTempl.setEnabled(false);
			}
		}
		
		if (templatesTable != null) {
			templ_createFromJob.setEnabled(false);
			templ_delete.setEnabled(false);
			templ_clear.setEnabled(false);
			
			if (jobsTable != null && jobsTable.getSelectedRowCount() == 1) {
				templ_createFromJob.setEnabled(true);
			}
			
			if (templatesTable.getSelectedRowCount() > 0) {
				templ_delete.setEnabled(true);
			}
			
			if (templatesTable.getRowCount() > 0) {
				templ_clear.setEnabled(true);
			}
		}
	}
	
	private class JobsTableMouseListener implements MouseListener {

		public void mouseClicked(MouseEvent e) {
			if (e != null && e.getClickCount() == 2) {
				List<RecordJob> selectedJobs = getSelectedRecordJobs(jobsTable);
				if (selectedJobs.size() == 1) {
					RecordJob selectedJob = selectedJobs.get(0);
					if (selectedJob.getState() != RecordJob.State.PROCESSING) {
						JobDialog jobDialog = new JobDialog(SwingGUI.this, selectedJob, appLayer);
						jobDialog.showDialog();
					}
				}
			} else {
				configureTableButtons();
			}
		}

		public void mouseEntered(MouseEvent e) {}

		public void mouseExited(MouseEvent e) {}

		public void mousePressed(MouseEvent e) {
			this.showPopupMenu(e);
		}

		public void mouseReleased(MouseEvent e) {
			this.showPopupMenu(e);
		}
		
		private void showPopupMenu(MouseEvent e) {
			if (e.isPopupTrigger()) {
				JTable table = (JTable)(e.getSource());
				Point p = e.getPoint();
				int row = table.rowAtPoint(p);
				int[] selectedRows = table.getSelectedRows();
				//figure out whether we have to reselect the current row under the pointer,
				//which is only the case if the already selected rows don't include the one under
				//the pointer yet
				boolean reSelect = true;
				for (int i = 0; i < selectedRows.length; i++) {
					if (row == selectedRows[i]) {
						reSelect = false;
						break;
					}
				}
				
				if (row != -1 && reSelect) {
					table.setRowSelectionInterval(row, row);
				}
				
				this.configurePopupMenu();
				configureTableButtons();
				jobsTablePopupMenu.show(e.getComponent(), e.getX(), e.getY());
			}
		}
		
		private void configurePopupMenu() {
			//Disable all buttons first
			jobs_contextmenu_edit.setEnabled(false);
			jobs_contextmenu_duplicate.setEnabled(false);
			jobs_contextmenu_applytempl.setEnabled(false);
			jobs_contextmenu_delete.setEnabled(false);
			jobs_contextmenu_resetstate_waiting.setEnabled(false);
			jobs_contextmenu_resetstate_done.setEnabled(false);
			jobs_contextmenu_showerror.setEnabled(false);
			jobs_contextmenu_start.setEnabled(false);
			for (JMenuItem pluginItem : jobs_contextmenu_runPluginMenuItems) {
				pluginItem.setEnabled(false);
			}
			
			//edit, duplicate, and show error buttons
			if (jobsTable.getSelectedRowCount() == 1) {
				jobs_contextmenu_edit.setEnabled(true);
				
				//Show error button
				List<RecordJob> selectedJobs = getSelectedRecordJobs(jobsTable);
				RecordJob selectedJob = selectedJobs.get(0);
				if (selectedJob.getState() == RecordJob.State.ERROR || selectedJob.getState() == RecordJob.State.ERROR_PLUGIN) {
					jobs_contextmenu_showerror.setEnabled(true);
				}
			}
			
			if (jobsTable.getSelectedRowCount() > 0) {
				jobs_contextmenu_duplicate.setEnabled(true);
				//Delete button
				RecordJob.State[] states = {RecordJob.State.PROCESSING};
				if (!checkJobStates(states, false)) {
					//none of the jobs is processing
					jobs_contextmenu_delete.setEnabled(true);
					jobs_contextmenu_resetstate_waiting.setEnabled(true);
					
					if (templatesTable.getSelectedRowCount() == 1) {
						jobs_contextmenu_applytempl.setEnabled(true);
					}
				}
				
				//Start button
				RecordJob.State[] states2 = {RecordJob.State.ERROR, RecordJob.State.DONE, RecordJob.State.PROCESSING, RecordJob.State.ERROR_PLUGIN};
				if (!checkJobStates(states2, true)) {
					//only enable start if none of the selected jobs as any of the States above
					//as the only job State that is not listed is "waiting", we only enable the button if all jobs are waiting
					jobs_contextmenu_start.setEnabled(true);
				}
				
				//reset to 'done' button
				RecordJob.State[] states3 = {RecordJob.State.ERROR, RecordJob.State.WAITING, RecordJob.State.PROCESSING};
				if (!checkJobStates(states3, true)) {
					//only enable the "reset to done" button when processes have the state DONE or ERROR_PLUGIN
					jobs_contextmenu_resetstate_done.setEnabled(true);
				}
				
				//plugin buttons, enable only when state of the job is DONE
				RecordJob.State[] states4 = {RecordJob.State.ERROR, RecordJob.State.WAITING, RecordJob.State.PROCESSING, RecordJob.State.ERROR_PLUGIN};
				if (!checkJobStates(states4, true)) {
					int counter = 0;
					for (JMenuItem pluginItem : jobs_contextmenu_runPluginMenuItems) {
						if (appLayer.getEncoderPlugins().get(counter).isEnabled()) {
							pluginItem.setEnabled(true);
						}
						counter++;
					}
				}
			}
		}
		
	}
	
	private class TemplatesTableMouseListener implements MouseListener {

		public void mouseClicked(MouseEvent e) {
			if (e != null && e.getClickCount() == 2) {
				List<RecordJob> selectedJobs = getSelectedRecordJobs(templatesTable);
				if (selectedJobs.size() == 1) {
					RecordJobTemplate selectedJob = (RecordJobTemplate) selectedJobs.get(0);
					JobDialog jobDialog = new JobDialog(SwingGUI.this, selectedJob, appLayer, JobDialog.EDIT_TEMPLATE);
					jobDialog.showDialog();
					configureTableButtons();
				}
			} else {
				configureTableButtons();
			}
		}

		public void mouseEntered(MouseEvent e) {}

		public void mouseExited(MouseEvent e) {}

		public void mousePressed(MouseEvent e) {
			this.showPopupMenu(e);
		}

		public void mouseReleased(MouseEvent e) {
			this.showPopupMenu(e);
		}
		
		private void showPopupMenu(MouseEvent e) {
			if (e.isPopupTrigger()) {
				JTable table = (JTable)(e.getSource());
				Point p = e.getPoint();
				int row = table.rowAtPoint(p);
				int[] selectedRows = table.getSelectedRows();
				//figure out whether we have to reselect the current row under the pointer,
				//which is only the case if the already selected rows don't include the one under
				//the pointer yet
				boolean reSelect = true;
				for (int i = 0; i < selectedRows.length; i++) {
					if (row == selectedRows[i]) {
						reSelect = false;
						break;
					}
				}
				
				if (row != -1 && reSelect) {
					table.setRowSelectionInterval(row, row);
				}
				
				this.configurePopupMenu();
				configureTableButtons();
				templatesTablePopupMenu.show(e.getComponent(), e.getX(), e.getY());
			}
		}
		
		private void configurePopupMenu() {
			//Various buttons
			templ_contextmenu_edit.setEnabled(false);
			templ_contextmenu_duplicate.setEnabled(false);
			templ_contextmenu_delete.setEnabled(false);
			
			//Edit button
			if (templatesTable.getSelectedRowCount() == 1) {
				templ_contextmenu_edit.setEnabled(true);
			}
			
			//Delete and duplicate button
			if (templatesTable.getSelectedRowCount() > 0) {
				templ_contextmenu_delete.setEnabled(true);
				templ_contextmenu_duplicate.setEnabled(true);
			}
		}
	}
		
	private void showAboutBox() {
        try {
            InputStream inStream = ClassLoader.getSystemResourceAsStream("about.html");
            StringBuffer out = new StringBuffer();
            byte[] b = new byte[4096];
            for (int n; (n = inStream.read(b)) != -1;) {
                out.append(new String(b, 0, n));
            }
            String htmlString = out.toString();
            htmlString = htmlString.replaceAll("[\\r\\n]", "");
            JOptionPane.showMessageDialog(this, htmlString, "About", JOptionPane.PLAIN_MESSAGE);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

	public void windowActivated(WindowEvent e) {}
	public void windowClosed(WindowEvent e) {}
	public void windowDeactivated(WindowEvent e) {}
	public void windowDeiconified(WindowEvent e) {}
	public void windowIconified(WindowEvent e) {}
	public void windowOpened(WindowEvent e) {}

	public void windowClosing(WindowEvent e) {
		this.shutDown();
	}

	private void shutDown() {
		if (this.appLayer.getState() == DemoRecorderApplication.STATE_WORKING) {
			int result = JOptionPane.showConfirmDialog(this, "There are still jobs being recorded. Are you sure you want to exit?", "Confirm close", JOptionPane.YES_NO_OPTION);
			if (result == JOptionPane.NO_OPTION) {
				return;
			}
		}
		saveTableStates(jobsTable);
		saveTableStates(templatesTable);
		saveTemplateTableContent();
		this.appLayer.shutDown();
		this.dispose();
		System.exit(0);
	}
	
	private void saveTemplateTableContent() {
		File path = DemoRecorderUtils.computeLocalFile(DemoRecorderApplication.PREFERENCES_DIRNAME, TEMPLATE_TABLE_CONTENT_FILENAME);
		RecordJobTemplatesTableModel tableModel = (RecordJobTemplatesTableModel) templatesTable.getModel();
		tableModel.saveTemplateListToFile(path);
	}
	
	private Icon getIcon(String iconString) {
		URL url = ClassLoader.getSystemResource("icons/" + iconString);
		Icon i = new ImageIcon(url);
		return i;
	}

}
