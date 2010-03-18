/*
 * Main.java
 *
 * Created on 16. Januar 2007, 15:24
 *
 * To change this template, choose Tools | Template Manager
 * and open the template in the editor.
 */

package objtomap;

import java.io.IOException;
import java.util.Vector;
import javax.swing.UIManager;

/**
 *
 * @author user
 */
public class Main {
    
    
    public static void main(String[] args) throws IOException {
        
        try {
            UIManager.setLookAndFeel(
                    UIManager.getSystemLookAndFeelClassName());
        } catch (Exception e) { }
        
        Configuration config = new Configuration();
        
        JFrameMain main = new JFrameMain(config);
        main.setVisible(true);
        
    }
}
