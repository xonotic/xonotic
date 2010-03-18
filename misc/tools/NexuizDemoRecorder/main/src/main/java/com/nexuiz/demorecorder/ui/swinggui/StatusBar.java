package com.nexuiz.demorecorder.ui.swinggui;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.Graphics;
import java.awt.SystemColor;

import javax.swing.BorderFactory;
import javax.swing.Icon;
import javax.swing.JLabel;
import javax.swing.JPanel;

public class StatusBar extends JPanel {

	private static final long serialVersionUID = -1471757496863555741L;
	private JLabel currentActivity = null;
	
	private static final String STATE_IDLE = "Idle";
	private static final String STATE_WORKING = "Working";

	public StatusBar() {
		BorderLayout borderLayout = new BorderLayout(0, 0);
		setLayout(borderLayout);
		JPanel rightPanel = new JPanel(new BorderLayout());
		rightPanel.add(new JLabel(new AngledLinesWindowsCornerIcon()), BorderLayout.SOUTH);
		rightPanel.setOpaque(false);

		add(rightPanel, BorderLayout.EAST);

		this.currentActivity = new JLabel("Idle");
		add(this.currentActivity, BorderLayout.WEST);
		setBackground(SystemColor.control);
		setBorder(BorderFactory.createMatteBorder(1, 0, 0, 0, Color.black));
	}
	
	/**
	 * Sets the state/display of the status bar to "idle" (false) or "working" (true).
	 * @param state
	 */
	public void showState(boolean state) {
		if (state) {
			currentActivity.setText(STATE_WORKING);
		} else {
			currentActivity.setText(STATE_IDLE);
		}
	}

	private static class AngledLinesWindowsCornerIcon implements Icon {
		private static final Color WHITE_LINE_COLOR = new Color(255, 255, 255);

		private static final Color GRAY_LINE_COLOR = new Color(172, 168, 153);
		private static final int WIDTH = 13;

		private static final int HEIGHT = 13;

		public int getIconHeight() {
			return HEIGHT;
		}

		public int getIconWidth() {
			return WIDTH;
		}

		public void paintIcon(Component c, Graphics g, int x, int y) {

			g.setColor(WHITE_LINE_COLOR);
			g.drawLine(0, 12, 12, 0);
			g.drawLine(5, 12, 12, 5);
			g.drawLine(10, 12, 12, 10);

			g.setColor(GRAY_LINE_COLOR);
			g.drawLine(1, 12, 12, 1);
			g.drawLine(2, 12, 12, 2);
			g.drawLine(3, 12, 12, 3);

			g.drawLine(6, 12, 12, 6);
			g.drawLine(7, 12, 12, 7);
			g.drawLine(8, 12, 12, 8);

			g.drawLine(11, 12, 12, 11);
			g.drawLine(12, 12, 12, 12);

		}
	}
}
