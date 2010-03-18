/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package imgtomap;

import java.awt.image.BufferedImage;
import java.awt.image.Raster;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.LinkedList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.imageio.ImageIO;

/**
 *
 * @author maik
 */
public class MapWriter {

    public int writeMap(Parameters p) {
        if (!(new File(p.infile).exists())) {
            return 1;
        }

        double[][] height = getHeightmap(p.infile);
        double[][] columns = getColumns(height);
        double units = 1d * p.pixelsize;
        double max = p.height;

        PrintWriter pw = null;
        try {
            pw = new PrintWriter(new FileOutputStream(new File(p.outfile)));
        } catch (FileNotFoundException ex) {
            Logger.getLogger(MapWriter.class.getName()).log(Level.SEVERE, null, ex);
            return 1;
        }

        // worldspawn start
        pw.print("{\n\"classname\" \"worldspawn\"\n");
        pw.print("\n\"gridsize\" \"128 128 256\"\n");
        pw.print("\n\"blocksize\" \"2048 2048 2048\"\n");

        double xmax = (columns.length - 1) * units;
        double ymax = (columns[0].length - 1) * units;

        if (p.skyfill) {
            List<Block> fillers = genSkyFillers(columns);
            for (Block b : fillers) {
                double x = b.x * units;
                double y = (b.y + b.ydim) * units;
                x = x > xmax ? xmax : x;
                y = y > ymax ? ymax : y;
                Vector3D p1 = new Vector3D(x, -y, -32.0);

                x = (b.x + b.xdim) * units;
                y = b.y * units;
                x = x > xmax ? xmax : x;
                y = y > ymax ? ymax : y;
                Vector3D p2 = new Vector3D(x, -y, p.skyheight);

                writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);
            }
        }

        if (p.sky) {
            // generate skybox
            int x = height.length - 1;
            int y = height[0].length - 1;

            // top
            Vector3D p1 = new Vector3D(0, -y * units, p.skyheight);
            Vector3D p2 = new Vector3D(x * units, 0, p.skyheight + 32.0);
            writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);

            // bottom
            p1 = new Vector3D(0, -y * units, -64.0);
            p2 = new Vector3D(x * units, 0, -32.0);
            writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);

            // north
            p1 = new Vector3D(0, 0, -32.0);
            p2 = new Vector3D(x * units, 32, p.skyheight);
            writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);

            // east
            p1 = new Vector3D(x * units, -y * units, -32.0);
            p2 = new Vector3D(x * units + 32.0, 0, p.skyheight);
            writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);

            // south
            p1 = new Vector3D(0, -y * units - 32, -32.0);
            p2 = new Vector3D(x * units, -y * units, p.skyheight);
            writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);


            // west
            p1 = new Vector3D(0 - 32.0, -y * units, -32.0);
            p2 = new Vector3D(0, 0, p.skyheight);
            writeBoxBrush(pw, p1, p2, false, p.skytexture, 1.0);

        }

        // genBlockers screws the columns array!
        // this should be the last step!
        if (p.visblockers) {
            List<Block> blockers = genBlockers(columns, 0.15);
            for (Block b : blockers) {
                double z = b.minheight * p.height - 1;
                z = Math.floor(z / 16);
                z = z * 16;

                if (z > 0) {
                    double x = b.x * units;
                    double y = (b.y + b.ydim) * units;
                    x = x > xmax ? xmax : x;
                    y = y > ymax ? ymax : y;
                    Vector3D p1 = new Vector3D(x, -y, -32.0);

                    x = (b.x + b.xdim) * units;
                    y = b.y * units;
                    x = x > xmax ? xmax : x;
                    y = y > ymax ? ymax : y;
                    Vector3D p2 = new Vector3D(x, -y, z);

                    writeBoxBrush(pw, p1, p2, false, "common/caulk", 1.0);
                }

            }
        }

        // worldspawn end
        pw.print("}\n");

        // func_group start
        pw.print("{\n\"classname\" \"func_group\"\n");
        pw.print("\n\"terrain\" \"1\"\n");
        // wander through grid
        for (int x = 0; x < height.length - 1; ++x) {
            for (int y = 0; y < height[0].length - 1; ++y) {

                boolean skip = getMinMaxForRegion(height, x, y, 2)[0] < 0;

                if (!skip) {

                    /*
                     * 
                     *      a +-------+ b
                     *       /       /|
                     *      /       / |
                     *     /       /  |
                     *  c +-------+ d + f   (e occluded, unused)
                     *    |       |  /
                     *    |       | /
                     *    |       |/
                     *  g +-------+ h
                     * 
                     */


                    // delta a - d
                    double grad1 = Math.abs(height[x][y] - height[x + 1][y + 1]);

                    /// delta b - c
                    double grad2 = Math.abs(height[x + 1][y] - height[x][y + 1]);

                    Vector3D a = new Vector3D(x * units, -y * units, Math.floor(height[x][y] * max));
                    Vector3D b = new Vector3D((x + 1) * units, -y * units, Math.floor(height[x + 1][y] * max));
                    Vector3D c = new Vector3D(x * units, -(y + 1) * units, Math.floor(height[x][y + 1] * max));
                    Vector3D d = new Vector3D((x + 1) * units, -(y + 1) * units, Math.floor(height[x + 1][y + 1] * max));
                    //Vector3D e = new Vector3D(x * units, -y * units, -16.0);
                    Vector3D f = new Vector3D((x + 1) * units, -y * units, -16.0);
                    Vector3D g = new Vector3D(x * units, -(y + 1) * units, -16.0);
                    Vector3D h = new Vector3D((x + 1) * units, -(y + 1) * units, -16.0);

                    if (grad1 > grad2) {
                        pw.print("{\n");
                        pw.print(getMapPlaneString(a, b, c, p.detail, p.texture, p.texturescale));
                        pw.print(getMapPlaneString(f, b, a, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(a, c, g, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(g, h, f, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(g, c, b, p.detail, "common/caulk", p.texturescale));
                        pw.print("}\n");


                        pw.print("{\n");
                        pw.print(getMapPlaneString(b, d, c, p.detail, p.texture, p.texturescale));
                        pw.print(getMapPlaneString(d, h, g, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(d, b, f, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(f, b, c, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(g, h, f, p.detail, "common/caulk", p.texturescale));
                        pw.print("}\n");

                    } else {

                        pw.print("{\n");
                        pw.print(getMapPlaneString(a, b, d, p.detail, p.texture, p.texturescale));
                        pw.print(getMapPlaneString(d, b, f, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(f, b, a, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(a, d, h, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(g, h, f, p.detail, "common/caulk", p.texturescale));
                        pw.print("}\n");


                        pw.print("{\n");
                        pw.print(getMapPlaneString(d, c, a, p.detail, p.texture, p.texturescale));
                        pw.print(getMapPlaneString(g, c, d, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(c, g, a, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(h, d, a, p.detail, "common/caulk", p.texturescale));
                        pw.print(getMapPlaneString(g, h, f, p.detail, "common/caulk", p.texturescale));
                        pw.print("}\n");
                    }
                }
            }
        }
        // func_group end
        pw.print("}\n");

        pw.close();
        return 0;
    }

    private void writeBoxBrush(PrintWriter pw, Vector3D p1, Vector3D p2, boolean detail, String texture, double scale) {
        Vector3D a = new Vector3D(p1.x, p2.y, p2.z);
        Vector3D b = p2;
        Vector3D c = new Vector3D(p1.x, p1.y, p2.z);
        Vector3D d = new Vector3D(p2.x, p1.y, p2.z);
        //Vector3D e unused
        Vector3D f = new Vector3D(p2.x, p2.y, p1.z);
        Vector3D g = p1;
        Vector3D h = new Vector3D(p2.x, p1.y, p1.z);

        pw.print("{\n");
        pw.print(getMapPlaneString(a, b, d, detail, texture, scale));
        pw.print(getMapPlaneString(d, b, f, detail, texture, scale));
        pw.print(getMapPlaneString(c, d, h, detail, texture, scale));
        pw.print(getMapPlaneString(a, c, g, detail, texture, scale));
        pw.print(getMapPlaneString(f, b, a, detail, texture, scale));
        pw.print(getMapPlaneString(g, h, f, detail, texture, scale));
        pw.print("}\n");

    }

    private String getMapPlaneString(Vector3D p1, Vector3D p2, Vector3D p3, boolean detail, String material, double scale) {
        int flag;
        if (detail) {
            flag = 134217728;
        } else {
            flag = 0;
        }
        return "( " + p1.x + " " + p1.y + " " + p1.z + " ) ( " + p2.x + " " + p2.y + " " + p2.z + " ) ( " + p3.x + " " + p3.y + " " + p3.z + " ) " + material + " 0 0 0 " + scale + " " + scale + " " + flag + " 0 0\n";
    }

    private double[][] getHeightmap(String file) {
        try {
            BufferedImage bimg = ImageIO.read(new File(file));
            Raster raster = bimg.getRaster();
            int x = raster.getWidth();
            int y = raster.getHeight();

            double[][] result = new double[x][y];

            for (int xi = 0; xi < x; ++xi) {
                for (int yi = 0; yi < y; ++yi) {
                    float[] pixel = raster.getPixel(xi, yi, (float[]) null);

                    int channels;
                    boolean alpha;
                    if (pixel.length == 3) {
                        // RGB
                        channels = 3;
                        alpha = false;
                    } else if (pixel.length == 4) {
                        // RGBA
                        channels = 3;
                        alpha = true;
                    } else if (pixel.length == 1) {
                        // grayscale
                        channels = 1;
                        alpha = false;
                    } else {
                        // grayscale with alpha
                        channels = 1;
                        alpha = true;
                    }

                    float tmp = 0f;
                    for (int i = 0; i < channels; ++i) {
                        tmp += pixel[i];
                    }
                    result[xi][yi] = tmp / (channels * 255f);

                    if (alpha) {
                        // mark this pixel to be skipped
                        if (pixel[pixel.length - 1] < 64.0) {
                            result[xi][yi] = -1.0;
                        }
                    }
                }
            }


            return result;
        } catch (IOException ex) {
            Logger.getLogger(MapWriter.class.getName()).log(Level.SEVERE, null, ex);
        }

        return null;
    }

    private double[][] getColumns(double[][] heights) {
        double[][] result = new double[heights.length][heights[0].length];

        for (int x = 0; x < heights.length; ++x) {
            for (int y = 0; y < heights[0].length; ++y) {
                result[x][y] = getMinMaxForRegion(heights, x, y, 2)[0];
            }
        }

        return result;
    }

    private double[] getMinMaxForRegion(double[][] field, int x, int y, int dim) {
        return getMinMaxForRegion(field, x, y, dim, dim);
    }

    private double[] getMinMaxForRegion(double[][] field, int x, int y, int xdim, int ydim) {
        double max = -100d;
        double min = 100d;

        for (int i = x; i < x + xdim; ++i) {
            for (int j = y; j < y + ydim; ++j) {
                if (i >= 0 && j >= 0 && i < field.length && j < field[0].length) {
                    min = field[i][j] < min ? field[i][j] : min;
                    max = field[i][j] > max ? field[i][j] : max;
                }
            }
        }

        double[] result = {min, max};
        return result;
    }

    private List<Block> genBlockers(double[][] columns, double delta) {

        Block[][] blockers = new Block[columns.length][columns[0].length];
        LinkedList<Block> result = new LinkedList<Block>();

        for (int x = 0; x < columns.length; ++x) {
            for (int y = 0; y < columns[0].length; ++y) {
                if (blockers[x][y] == null && columns[x][y] >= 0) {
                    // this pixel isn't covered by a blocker yet... so let's create one!
                    Block b = new Block();
                    result.add(b);
                    b.x = x;
                    b.y = y;
                    b.minheight = b.origheight = columns[x][y];

                    // grow till the delta hits
                    int xdim = 1;
                    int ydim = 1;
                    boolean xgrow = true;
                    boolean ygrow = true;
                    double min = b.minheight;
                    for (; xdim < columns.length && ydim < columns[0].length;) {
                        double[] minmax = getMinMaxForRegion(columns, x, y, xdim + 1, ydim);
                        if (Math.abs(b.origheight - minmax[0]) > delta || Math.abs(b.origheight - minmax[1]) > delta) {
                            xgrow = false;
                        }

                        minmax = getMinMaxForRegion(columns, x, y, xdim, ydim + 1);
                        if (Math.abs(b.origheight - minmax[0]) > delta || Math.abs(b.origheight - minmax[1]) > delta) {
                            ygrow = false;
                        }

                        min = minmax[0];

                        if (xgrow) {
                            ++xdim;
                        }
                        if (ygrow) {
                            ++ydim;
                        }

                        minmax = getMinMaxForRegion(columns, x, y, xdim, ydim);
                        min = minmax[0];

                        if (!(xgrow || ygrow)) {
                            break;
                        }
                    }

                    b.xdim = xdim;
                    b.ydim = ydim;
                    b.minheight = min;

                    for (int i = x; i < x + b.xdim; ++i) {
                        for (int j = y; j < y + b.ydim; ++j) {
                            if (i >= 0 && j >= 0 && i < blockers.length && j < blockers[0].length) {
                                blockers[i][j] = b;
                                columns[i][j] = -1337.0;
                            }
                        }
                    }

                }
            }
        }
        return result;
    }

    private List<Block> genSkyFillers(double[][] columns) {

        double delta = 0;

        for (int x = 0; x < columns.length; ++x) {
            for (int y = 0; y < columns[0].length; ++y) {
                if (columns[x][y] < 0) {
                    // this is a skipped block, see if it neighbours a
                    // relevant block
                    if (getMinMaxForRegion(columns, x - 1, y - 1, 3)[1] >= 0) {
                        columns[x][y] = -100d;
                    }
                }
            }
        }


        Block[][] fillers = new Block[columns.length][columns[0].length];
        LinkedList<Block> result = new LinkedList<Block>();

        for (int x = 0; x < columns.length; ++x) {
            for (int y = 0; y < columns[0].length; ++y) {
                if (fillers[x][y] == null && columns[x][y] == -100d) {
                    // this pixel is marked to be skyfill
                    Block b = new Block();
                    result.add(b);
                    b.x = x;
                    b.y = y;
                    b.minheight = b.origheight = columns[x][y];

                    // grow till the delta hits
                    int xdim = 1;
                    int ydim = 1;
                    boolean xgrow = true;
                    boolean ygrow = true;
                    double min = b.minheight;
                    for (; xdim < columns.length && ydim < columns[0].length;) {
                        double[] minmax = getMinMaxForRegion(columns, x, y, xdim + 1, ydim);
                        if (Math.abs(b.origheight - minmax[0]) > delta || Math.abs(b.origheight - minmax[1]) > delta) {
                            xgrow = false;
                        }

                        minmax = getMinMaxForRegion(columns, x, y, xdim, ydim + 1);
                        if (Math.abs(b.origheight - minmax[0]) > delta || Math.abs(b.origheight - minmax[1]) > delta) {
                            ygrow = false;
                        }

                        min = minmax[0];

                        if (xgrow) {
                            ++xdim;
                        }
                        if (ygrow) {
                            ++ydim;
                        }

                        minmax = getMinMaxForRegion(columns, x, y, xdim, ydim);
                        min = minmax[0];

                        if (!(xgrow || ygrow)) {
                            break;
                        }
                    }

                    b.xdim = xdim;
                    b.ydim = ydim;
                    b.minheight = min;

                    for (int i = x; i < x + b.xdim; ++i) {
                        for (int j = y; j < y + b.ydim; ++j) {
                            if (i >= 0 && j >= 0 && i < fillers.length && j < fillers[0].length) {
                                fillers[i][j] = b;
                                columns[i][j] = -1337.0;
                            }
                        }
                    }

                }
            }
        }
        return result;
    }

    private class Vector3D {

        public double x,  y,  z;

        public Vector3D() {
            this(0.0, 0.0, 0.0);
        }

        public Vector3D(double x, double y, double z) {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        public Vector3D crossproduct(Vector3D p1) {
            Vector3D result = new Vector3D();

            result.x = this.y * p1.z - this.z * p1.y;
            result.y = this.z * p1.x - this.x * p1.z;
            result.z = this.x * p1.y - this.y * p1.x;

            return result;
        }

        public double dotproduct(Vector3D p1) {
            return this.x * p1.x + this.y * p1.y + this.z * p1.z;
        }

        public Vector3D substract(Vector3D p1) {
            Vector3D result = new Vector3D();

            result.x = this.x - p1.x;
            result.y = this.y - p1.y;
            result.z = this.z - p1.z;

            return result;
        }

        public void scale(double factor) {
            x *= factor;
            y *= factor;
            z *= factor;
        }

        public double length() {
            return Math.sqrt((x * x) + (y * y) + (z * z));
        }

        public void normalize() {
            double l = length();

            x /= l;
            y /= l;
            z /= l;
        }
    }

    private class Block {

        public int x,  y,  xdim,  ydim;
        public double origheight,  minheight;
    }
}