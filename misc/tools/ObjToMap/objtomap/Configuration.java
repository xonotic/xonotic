
package objtomap;

import java.util.Vector;

public class Configuration {
    
    public double brush_thickness, scale, texture_scale, minz;
    public boolean detail, autotexture, simpleterrain;
    public String objfile, mapfile;
    public Vector autotexturing;
    
    
    /** Creates a new instance of Configuration */
    public Configuration() {
        brush_thickness = 4.0;
        texture_scale = 0.5;
        scale = 128.0;
        detail = true;
        autotexturing = new Vector();
    }
    
}
