/*
 * Created on 08.02.2007
 *
 */
package com.nexuiz.demorecorder.ui.swinggui.utils;

import java.awt.Component;
import java.beans.DefaultPersistenceDelegate;
import java.beans.XMLEncoder;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

import javax.swing.SortOrder;
import javax.swing.RowSorter.SortKey;
import javax.swing.table.TableColumn;
import javax.swing.table.TableColumnModel;

import org.jdesktop.swingx.JXTable;
import org.jdesktop.swingx.JXTaskPane;
import org.jdesktop.swingx.sort.SortUtils;
import org.jdesktop.swingx.table.TableColumnExt;

/**
 * Container class for SwingX specific SessionStorage Properties. Is Factory for
 * custom PersistanceDelegates
 */
public class XProperties {

	/**
	 * 
	 * Registers all custom PersistenceDelegates needed by contained Property
	 * classes.
	 * <p>
	 * 
	 * PersistenceDelegates are effectively static properties shared by all
	 * encoders. In other words: Register once on an arbitrary encoder makes
	 * them available for all. Example usage:
	 * 
	 * <pre>
	 * <code>
	 * new XProperties.registerPersistenceDelegates();
	 * </code>
	 * </pre>
	 * 
	 * PENDING JW: cleanup for 1.6 sorting/filtering incomplete. Missing storage
	 * - multiple sort keys
	 * 
	 * PENDING JW: except for comparators: didn't before and is not state that's
	 * configurable by users ... so probably won't, not sure, need to revisit -
	 * comparator (?) - filters (?) - renderers/stringvalues (?) - enhanced
	 * sort-related table state (?)
	 */
	public void registerPersistenceDelegates() {
		XMLEncoder encoder = new XMLEncoder(System.out);
		encoder.setPersistenceDelegate(SortKeyState.class, new DefaultPersistenceDelegate(
				new String[] { "ascending", "modelIndex" }));
		encoder.setPersistenceDelegate(ColumnState.class, new DefaultPersistenceDelegate(
				new String[] { "width", "preferredWidth", "modelIndex", "visible", "viewIndex" }));
		encoder.setPersistenceDelegate(XTableState.class, new DefaultPersistenceDelegate(
				new String[] { "columnStates", "sortKeyState", "horizontalScrollEnabled" }));
	}

	/**
	 * Session storage support for JXTaskPane.
	 */
	public static class XTaskPaneProperty implements Serializable {

		private static final long serialVersionUID = -4069436038178318216L;

		public Object getSessionState(Component c) {
			checkComponent(c);
			return new XTaskPaneState(((JXTaskPane) c).isCollapsed());
		}

		public void setSessionState(Component c, Object state) {
			checkComponent(c);
			if ((state != null) && !(state instanceof XTaskPaneState)) {
				throw new IllegalArgumentException("invalid state");
			}
			((JXTaskPane) c).setCollapsed(((XTaskPaneState) state).isCollapsed());
		}

		private void checkComponent(Component component) {
			if (component == null) {
				throw new IllegalArgumentException("null component");
			}
			if (!(component instanceof JXTaskPane)) {
				throw new IllegalArgumentException("invalid component");
			}
		}

	}

	public static class XTaskPaneState implements Serializable {
		private static final long serialVersionUID = 3363688961112031969L;
		private boolean collapsed;

		public XTaskPaneState() {
			this(false);
		}

		/**
		 * @param b
		 */
		public XTaskPaneState(boolean collapsed) {
			this.setCollapsed(collapsed);
		}

		/**
		 * @param collapsed
		 *            the collapsed to set
		 */
		public void setCollapsed(boolean collapsed) {
			this.collapsed = collapsed;
		}

		/**
		 * @return the collapsed
		 */
		public boolean isCollapsed() {
			return collapsed;
		}

	}

	/**
	 * Session storage support for JXTable.
	 */
	public static class XTableProperty implements Serializable {

		private static final long serialVersionUID = -5064142292091374301L;

		public Object getSessionState(Component c) {
			checkComponent(c);
			JXTable table = (JXTable) c;
			List<ColumnState> columnStates = new ArrayList<ColumnState>();
			List<TableColumn> columns = table.getColumns(true);
			List<TableColumn> visibleColumns = table.getColumns();
			for (TableColumn column : columns) {
				columnStates.add(new ColumnState((TableColumnExt) column, visibleColumns
						.indexOf(column)));
			}
			XTableState tableState = new XTableState(columnStates
					.toArray(new ColumnState[columnStates.size()]));
			tableState.setHorizontalScrollEnabled(table.isHorizontalScrollEnabled());
			List<? extends SortKey> sortKeys = null;
			if (table.getRowSorter() != null) {
				sortKeys = table.getRowSorter().getSortKeys();
			}
			// PENDING: store all!
			if ((sortKeys != null) && (sortKeys.size() > 0)) {
				tableState.setSortKey(sortKeys.get(0));
			}
			return tableState;
		}

		public void setSessionState(Component c, Object state) {
			checkComponent(c);
			JXTable table = (JXTable) c;
			XTableState tableState = ((XTableState) state);
			ColumnState[] columnState = tableState.getColumnStates();
			List<TableColumn> columns = table.getColumns(true);
			if (canRestore(columnState, columns)) {
				for (int i = 0; i < columnState.length; i++) {
					columnState[i].configureColumn((TableColumnExt) columns.get(i));
				}
				restoreVisibleSequence(columnState, table.getColumnModel());
			}
			table.setHorizontalScrollEnabled(tableState.getHorizontalScrollEnabled());
			if (tableState.getSortKey() != null) {
				table.getRowSorter()
						.setSortKeys(Collections.singletonList(tableState.getSortKey()));
			}
		}

		private void restoreVisibleSequence(ColumnState[] columnStates, TableColumnModel model) {
			List<ColumnState> visibleStates = getSortedVisibleColumnStates(columnStates);
			for (int i = 0; i < visibleStates.size(); i++) {
				TableColumn column = model.getColumn(i);
				int modelIndex = visibleStates.get(i).getModelIndex();
				if (modelIndex != column.getModelIndex()) {
					int currentIndex = -1;
					for (int j = i + 1; j < model.getColumnCount(); j++) {
						TableColumn current = model.getColumn(j);
						if (current.getModelIndex() == modelIndex) {
							currentIndex = j;
							break;
						}
					}
					model.moveColumn(currentIndex, i);
				}
			}

		}

		private List<ColumnState> getSortedVisibleColumnStates(ColumnState[] columnStates) {
			List<ColumnState> visibleStates = new ArrayList<ColumnState>();
			for (ColumnState columnState : columnStates) {
				if (columnState.getVisible()) {
					visibleStates.add(columnState);
				}
			}
			Collections.sort(visibleStates, new VisibleColumnIndexComparator());
			return visibleStates;
		}

		/**
		 * Returns a boolean to indicate if it's reasonably safe to restore the
		 * properties of columns in the list from the columnStates. Here:
		 * returns true if the length of both are the same and the modelIndex of
		 * the items at the same position are the same, otherwise returns false.
		 * 
		 * @param columnState
		 * @param columns
		 * @return
		 */
		private boolean canRestore(ColumnState[] columnState, List<TableColumn> columns) {
			if ((columnState == null) || (columnState.length != columns.size()))
				return false;
			for (int i = 0; i < columnState.length; i++) {
				if (columnState[i].getModelIndex() != columns.get(i).getModelIndex()) {
					return false;
				}
			}
			return true;
		}

		private void checkComponent(Component component) {
			if (component == null) {
				throw new IllegalArgumentException("null component");
			}
			if (!(component instanceof JXTable)) {
				throw new IllegalArgumentException("invalid component - expected JXTable");
			}
		}

	}

	public static class XTableState implements Serializable {
		private static final long serialVersionUID = -3566913244872587438L;
		ColumnState[] columnStates = new ColumnState[0];
		boolean horizontalScrollEnabled;
		SortKeyState sortKeyState;

		public XTableState(ColumnState[] columnStates, SortKeyState sortKeyState,
				boolean horizontalScrollEnabled) {
			this.columnStates = copyColumnStates(columnStates);
			this.sortKeyState = sortKeyState;
			setHorizontalScrollEnabled(horizontalScrollEnabled);

		}

		public void setSortKey(SortKey sortKey) {
			this.sortKeyState = new SortKeyState(sortKey);

		}

		private SortKey getSortKey() {
			if (sortKeyState != null) {
				return sortKeyState.getSortKey();
			}
			return null;
		}

		public XTableState(ColumnState[] columnStates) {
			this.columnStates = copyColumnStates(columnStates);
		}

		public ColumnState[] getColumnStates() {
			return copyColumnStates(this.columnStates);
		}

		public boolean getHorizontalScrollEnabled() {
			return horizontalScrollEnabled;
		}

		public void setHorizontalScrollEnabled(boolean horizontalScrollEnabled) {
			this.horizontalScrollEnabled = horizontalScrollEnabled;
		}

		private ColumnState[] copyColumnStates(ColumnState[] states) {
			if (states == null) {
				throw new IllegalArgumentException("invalid columnWidths");
			}
			ColumnState[] copy = new ColumnState[states.length];
			System.arraycopy(states, 0, copy, 0, states.length);
			return copy;
		}

		public SortKeyState getSortKeyState() {
			return sortKeyState;
		}
	}

	/**
	 * Quick hack to make SortKey encodable. How to write a PersistenceDelegate
	 * for a SortKey? Boils down to how to write a delegate for the
	 * uninstantiable class (SwingX) SortOrder which does enum-mimickry (defines
	 * privately intantiated constants)
	 * 
	 */
	public static class SortKeyState implements Serializable {
		private static final long serialVersionUID = 5819342622261460894L;

		int modelIndex;

		boolean ascending;

		/**
		 * Constructor used by the custom PersistenceDelegate.
		 * 
		 * @param ascending
		 * @param modelIndex
		 * @param comparator
		 */
		public SortKeyState(boolean ascending, int modelIndex) {
			this.ascending = ascending;
			this.modelIndex = modelIndex;
		}

		/**
		 * Constructor used by property.
		 * 
		 * @param sortKey
		 */
		public SortKeyState(SortKey sortKey) {
			this(SortUtils.isAscending(sortKey.getSortOrder()), sortKey.getColumn());
		}

		protected SortKey getSortKey() {
			SortOrder sortOrder = getAscending() ? SortOrder.ASCENDING : SortOrder.DESCENDING;
			return new SortKey(getModelIndex(), sortOrder);
		}

		public boolean getAscending() {
			return ascending;
		}

		public int getModelIndex() {
			return modelIndex;
		}
	}

	public static class ColumnState implements Serializable {
		private static final long serialVersionUID = 6037947151025126049L;
		private int width;
		private int preferredWidth;
		private int modelIndex;
		private boolean visible;
		private int viewIndex;

		/**
		 * Constructor used by the custom PersistenceDelegate.
		 * 
		 * @param width
		 * @param preferredWidth
		 * @param modelColumn
		 * @param visible
		 * @param viewIndex
		 */
		public ColumnState(int width, int preferredWidth, int modelColumn, boolean visible,
				int viewIndex) {
			this.width = width;
			this.preferredWidth = preferredWidth;
			this.modelIndex = modelColumn;
			this.visible = visible;
			this.viewIndex = viewIndex;
		}

		/**
		 * Constructor used by the Property.
		 * 
		 * @param columnExt
		 * @param viewIndex
		 */
		public ColumnState(TableColumnExt columnExt, int viewIndex) {
			this(columnExt.getWidth(), columnExt.getPreferredWidth(), columnExt.getModelIndex(),
					columnExt.isVisible(), viewIndex);
		}

		/**
		 * Restores column properties if the model index is the same as the
		 * column's model index. Does nothing otherwise.
		 * <p>
		 * 
		 * Here the properties are: width, preferredWidth, visible.
		 * 
		 * @param columnExt
		 *            the column to configure
		 */
		public void configureColumn(TableColumnExt columnExt) {
			if (modelIndex != columnExt.getModelIndex())
				return;
			columnExt.setPreferredWidth(preferredWidth);
			columnExt.setWidth(width);
			columnExt.setVisible(visible);
		}

		public int getModelIndex() {
			return modelIndex;
		}

		public int getViewIndex() {
			return viewIndex;
		}

		public boolean getVisible() {
			return visible;
		}

		public int getWidth() {
			return width;
		}

		public int getPreferredWidth() {
			return preferredWidth;
		}

	}

	public static class VisibleColumnIndexComparator implements Comparator<Object> {

		public int compare(Object o1, Object o2) {
			return ((ColumnState) o1).getViewIndex() - ((ColumnState) o2).getViewIndex();
		}

	}

}
