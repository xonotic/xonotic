package com.nexuiz.demorecorder.ui.swinggui.tablemodels;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.ArrayList;
import java.util.List;

import javax.swing.JOptionPane;
import javax.swing.table.AbstractTableModel;

import org.jdesktop.swingx.JXTable;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.DemoRecorderException;
import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.ui.swinggui.RecordJobTemplate;
import com.nexuiz.demorecorder.ui.swinggui.SwingGUI;

/**
 * Columns:
 * - Job Name
 * - Engine path
 * - Engine parameters
 * - Demo file
 * - Relative demo path
 * - dpvideo path
 * - video destination
 * - execute before cap
 * - execute after cap
 * - start second
 * - end second
 * - status
 * @author Marius
 *
 */
public class RecordJobTemplatesTableModel extends AbstractTableModel {
	
	private static final long serialVersionUID = 6541517890817708306L;
	
	public static final int TEMPLATE_NAME = 0;
	public static final int TEMPLATE_SUMMARY = 1;
	public static final int JOB_NAME = 2;
	public static final int ENGINE_PATH = 3;
	public static final int ENGINE_PARAMETERS = 4;
	public static final int DEMO_FILE_PATH = 5;
	public static final int RELATIVE_DEMO_PATH = 6;
	public static final int DPVIDEO_PATH = 7;
	public static final int VIDEO_DESTINATION_PATH = 8;
	public static final int EXECUTE_BEFORE_CAP = 9;
	public static final int EXECUTE_AFTER_CAP = 10;
	
	private static final int columns[] = {
		TEMPLATE_NAME,
		TEMPLATE_SUMMARY,
		JOB_NAME,
		ENGINE_PATH,
		ENGINE_PARAMETERS,
		DEMO_FILE_PATH,
		RELATIVE_DEMO_PATH,
		DPVIDEO_PATH,
		VIDEO_DESTINATION_PATH,
		EXECUTE_BEFORE_CAP,
		EXECUTE_AFTER_CAP
	};
	
	private List<RecordJobTemplate> templates;
	
	public RecordJobTemplatesTableModel() {
		templates = new ArrayList<RecordJobTemplate>();
		
		//load table content
		File path = DemoRecorderUtils.computeLocalFile(DemoRecorderApplication.PREFERENCES_DIRNAME, SwingGUI.TEMPLATE_TABLE_CONTENT_FILENAME);
		this.loadTemplateListFromFile(path, true);
	}
	
	public void deleteRecordJobTemplate(int modelRowIndex, int viewRowIndex) {
		try {
			this.templates.remove(modelRowIndex);
			fireTableRowsDeleted(viewRowIndex, viewRowIndex);
		} catch (IndexOutOfBoundsException e) {
			throw new DemoRecorderException("Couldn't find correspondig template for modelRowIndex " + modelRowIndex
					+ " and viewRowIndex " + viewRowIndex, e);
		}
	}
	
	public void addRecordJobTemplate(RecordJobTemplate template) {
		this.templates.add(template);
		int position = this.templates.size() - 1;
		fireTableRowsInserted(position, position);
	}
	
	public RecordJobTemplate getRecordJobTemplate(int modelRowIndex) {
		return this.templates.get(modelRowIndex);
	}

	public int getColumnCount() {
		return columns.length;
	}

	public int getRowCount() {
		return this.templates.size();
	}
	
	public void saveTemplateListToFile(File path) {
		DemoRecorderUtils.attemptFileCreation(path);
		
		String exceptionMessage = "Could not save the templates to file " + path.getAbsolutePath();
		
		if (!path.exists()) {
			DemoRecorderException ex = new DemoRecorderException(exceptionMessage);
			DemoRecorderUtils.showNonCriticalErrorDialog(ex);
			return;
		}
		
		try {
			FileOutputStream fout = new FileOutputStream(path);
			ObjectOutputStream oos = new ObjectOutputStream(fout);
			oos.writeObject(this.templates);
			oos.close();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog(exceptionMessage, e, true);
		}
	}
	
	@SuppressWarnings("unchecked")
	private int loadTemplateListFromFile(File path, boolean overwrite) {
		if (!path.exists()) {
			return 0;
		}
		
		List<RecordJobTemplate> newTemplateList;
		try {
			FileInputStream fin = new FileInputStream(path);
			ObjectInputStream ois = new ObjectInputStream(fin);
			newTemplateList = (List<RecordJobTemplate>) ois.readObject();
			if (overwrite) {
				this.templates = newTemplateList;
			} else {
				this.templates.addAll(newTemplateList);
			}
			return newTemplateList.size();
		} catch (Exception e) {
			DemoRecorderUtils.showNonCriticalErrorDialog("Could not load the templates from file " + path.getAbsolutePath(), e, true);
			return 0;
		}
		
	}
	
	public void loadNewTemplateList(SwingGUI gui, File path, JXTable templatesTable) {
		int result = JOptionPane.showConfirmDialog(gui, "Do you want to overwrite the current template list? When pressing 'no' the loaded templates will be added to the current list!", "Confirm overwrite", JOptionPane.YES_NO_OPTION);
		boolean overwrite = false;
		if (result == JOptionPane.YES_OPTION) {
			overwrite = true;
		}
		int count = loadTemplateListFromFile(path, overwrite);
		fireTableDataChanged();
		if (count > 0) {
			templatesTable.setRowSelectionInterval(templatesTable.getRowCount() - count, templatesTable.getRowCount() - 1);
		}
	}

	public Object getValueAt(int rowIndex, int columnIndex) {
		RecordJobTemplate template = this.templates.get(rowIndex);
		if (template == null) {
			return null;
		}
		
		if (columnIndex < 0 || columnIndex >= columns.length) {
			return null;
		}
		
		String cellData = "UNDEF";
		switch (columnIndex) {
		case TEMPLATE_NAME:
			cellData = template.getName(); break;
		case TEMPLATE_SUMMARY:
			cellData = template.getSummary(); break;
		case JOB_NAME:
			cellData = template.getJobName(); break;
		case ENGINE_PATH:
			cellData = template.getEnginePath().getAbsolutePath(); break;
		case ENGINE_PARAMETERS:
			cellData = template.getEngineParameters(); break;
		case DEMO_FILE_PATH:
			cellData = DemoRecorderUtils.getJustFileNameOfPath(template.getDemoFile()); break;
		case RELATIVE_DEMO_PATH:
			cellData = template.getRelativeDemoPath(); break;
		case DPVIDEO_PATH:
			cellData = template.getDpVideoPath().getAbsolutePath(); break;
		case VIDEO_DESTINATION_PATH:
			cellData = template.getVideoDestination().getAbsolutePath(); break;
		case EXECUTE_BEFORE_CAP:
			cellData = template.getExecuteBeforeCap(); break;
		case EXECUTE_AFTER_CAP:
			cellData = template.getExecuteAfterCap(); break;
		}
		
		return cellData;
	}

	@Override
	public String getColumnName(int column) {
		if (column < 0 || column >= columns.length) {
			return "";
		}
		
		String columnName = "UNDEFINED";
		switch (column) {
		case TEMPLATE_NAME:
			columnName = "Name"; break;
		case TEMPLATE_SUMMARY:
			columnName = "Summary"; break;
		case JOB_NAME:
			columnName = "Job name"; break;
		case ENGINE_PATH:
			columnName = "Engine path"; break;
		case ENGINE_PARAMETERS:
			columnName = "Engine parameters"; break;
		case DEMO_FILE_PATH:
			columnName = "Demo directory"; break;
		case RELATIVE_DEMO_PATH:
			columnName = "Relative demo path"; break;
		case DPVIDEO_PATH:
			columnName = "DPVideo path"; break;
		case VIDEO_DESTINATION_PATH:
			columnName = "Video destination"; break;
		case EXECUTE_BEFORE_CAP:
			columnName = "Exec before"; break;
		case EXECUTE_AFTER_CAP:
			columnName = "Exec after"; break;
		}
		
		return columnName;
	}
	
	public List<RecordJobTemplate> getRecordJobTemplates() {
		return this.templates;
	}
}
