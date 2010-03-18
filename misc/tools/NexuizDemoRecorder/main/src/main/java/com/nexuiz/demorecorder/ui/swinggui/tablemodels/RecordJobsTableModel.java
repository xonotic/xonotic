package com.nexuiz.demorecorder.ui.swinggui.tablemodels;

import java.io.File;
import java.util.List;

import javax.swing.JOptionPane;
import javax.swing.table.AbstractTableModel;

import org.jdesktop.swingx.JXTable;

import com.nexuiz.demorecorder.application.DemoRecorderApplication;
import com.nexuiz.demorecorder.application.DemoRecorderException;
import com.nexuiz.demorecorder.application.DemoRecorderUtils;
import com.nexuiz.demorecorder.application.jobs.RecordJob;
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
public class RecordJobsTableModel extends AbstractTableModel {
	
	private static final long serialVersionUID = 5024144640874313910L;
	
	public static final int JOB_NAME = 0;
	public static final int ENGINE_PATH = 1;
	public static final int ENGINE_PARAMETERS = 2;
	public static final int DEMO_FILE_PATH = 3;
	public static final int RELATIVE_DEMO_PATH = 4;
	public static final int DPVIDEO_PATH = 5;
	public static final int VIDEO_DESTINATION_PATH = 6;
	public static final int EXECUTE_BEFORE_CAP = 7;
	public static final int EXECUTE_AFTER_CAP = 8;
	public static final int START_SECOND = 9;
	public static final int END_SECOND = 10;
	public static final int STATUS = 11;
	
	private static final int columns[] = {
		JOB_NAME,
		ENGINE_PATH,
		ENGINE_PARAMETERS,
		DEMO_FILE_PATH,
		RELATIVE_DEMO_PATH,
		DPVIDEO_PATH,
		VIDEO_DESTINATION_PATH,
		EXECUTE_BEFORE_CAP,
		EXECUTE_AFTER_CAP,
		START_SECOND,
		END_SECOND,
		STATUS
	};
	
	private DemoRecorderApplication appLayer;
	private List<RecordJob> jobList = null;
	
	public RecordJobsTableModel(DemoRecorderApplication appLayer) {
		this.appLayer = appLayer;
		this.jobList = this.appLayer.getRecordJobs();
	}
	
	public void deleteRecordJob(int modelRowIndex, int viewRowIndex) {
		try {
			RecordJob job = this.jobList.get(modelRowIndex);
			if (this.appLayer.deleteRecordJob(job)) {
				this.jobList.remove(job);
				fireTableRowsDeleted(viewRowIndex, viewRowIndex);
			}
		} catch (IndexOutOfBoundsException e) {
			throw new DemoRecorderException("Couldn't find correspondig job for modelRowIndex " + modelRowIndex
					+ " and viewRowIndex " + viewRowIndex, e);
		}
	}
	
	public void loadNewJobQueue(SwingGUI gui, File path, JXTable jobsTable) {
		int result = JOptionPane.showConfirmDialog(gui, "Do you want to overwrite the current job queue? When pressing 'no' the loaded jobs will be added to the current queue!", "Confirm overwrite", JOptionPane.YES_NO_OPTION);
		boolean overwrite = false;
		if (result == JOptionPane.YES_OPTION) {
			overwrite = true;
		}
		int count = this.appLayer.loadJobQueue(path, overwrite);
		this.jobList = this.appLayer.getRecordJobs();
		fireTableDataChanged();
		if (count > 0) {
			jobsTable.setRowSelectionInterval(jobsTable.getRowCount() - count, jobsTable.getRowCount() - 1);
		}
	}
	
	public RecordJob getRecordJob(int modelRowIndex) {
		return this.jobList.get(modelRowIndex);
	}

	public int getColumnCount() {
		return columns.length;
	}

	public int getRowCount() {
		return this.jobList.size();
	}

	public Object getValueAt(int rowIndex, int columnIndex) {
		RecordJob job = this.jobList.get(rowIndex);
		if (job == null) {
			return null;
		}
		
		if (columnIndex < 0 || columnIndex >= columns.length) {
			return null;
		}
		
		String cellData = "UNDEF";
		switch (columnIndex) {
		case JOB_NAME:
			cellData = job.getJobName(); break;
		case ENGINE_PATH:
			cellData = job.getEnginePath().getAbsolutePath(); break;
		case ENGINE_PARAMETERS:
			cellData = job.getEngineParameters(); break;
		case DEMO_FILE_PATH:
			cellData = DemoRecorderUtils.getJustFileNameOfPath(job.getDemoFile()); break;
		case RELATIVE_DEMO_PATH:
			cellData = job.getRelativeDemoPath(); break;
		case DPVIDEO_PATH:
			cellData = job.getDpVideoPath().getAbsolutePath(); break;
		case VIDEO_DESTINATION_PATH:
			cellData = job.getVideoDestination().getAbsolutePath(); break;
		case EXECUTE_BEFORE_CAP:
			cellData = job.getExecuteBeforeCap(); break;
		case EXECUTE_AFTER_CAP:
			cellData = job.getExecuteAfterCap(); break;
		case START_SECOND:
			cellData = String.valueOf(job.getStartSecond()); break;
		case END_SECOND:
			cellData = String.valueOf(job.getEndSecond()); break;
		case STATUS:
			if (job.getState() == RecordJob.State.DONE) {
				cellData = "done";
			} else if (job.getState() == RecordJob.State.ERROR) {
				cellData = "error";
			} else if (job.getState() == RecordJob.State.ERROR_PLUGIN) {
				cellData = "plug-in error";
			} else if (job.getState() == RecordJob.State.PROCESSING) {
				cellData = "processing";
			} else if (job.getState() == RecordJob.State.WAITING) {
				cellData = "waiting";
			}
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
		case JOB_NAME:
			columnName = "Name"; break;
		case ENGINE_PATH:
			columnName = "Engine path"; break;
		case ENGINE_PARAMETERS:
			columnName = "Engine parameters"; break;
		case DEMO_FILE_PATH:
			columnName = "Demo name"; break;
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
		case START_SECOND:
			columnName = "Start"; break;
		case END_SECOND:
			columnName = "End"; break;
		case STATUS:
			columnName = "Status"; break;
		}
		
		return columnName;
	}
	
	public List<RecordJob> getRecordJobs() {
		return this.jobList;
	}
}
