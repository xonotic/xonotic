/* This code is *ugly*. It may blind you.
 *
 * I hereby pollute the software world by putting this into public domain.
 *
 * SavageX
 */


package objtomap;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.Vector;

public class ObjToMap {
    
    private Vector points, faces;
    private Configuration config;
    
    public ObjToMap(Configuration c) {
        config = c;
    }
    
    public void parseOBJ() throws IOException {
        
        points = new Vector();
        faces = new Vector();
        double scale = config.scale;
        config.simpleterrain = true;
        config.minz = Double.MAX_VALUE;
        
        
        BufferedReader in = null;
        try {
            in = new BufferedReader(new FileReader(config.objfile));
        } catch(Exception e) {
            System.err.println("Input file not found!");
            return;
        }
        
        String currentmat = "common/caulk";
        
        while(in.ready()) {
            String line = in.readLine();
            line.trim();
            line = line.replaceAll("  ", " ");
            String[] tokens = line.split(" ");
            if(tokens.length > 1) {
                
                if(tokens[0].equals("v")) {
                    // vertices
                    Vector3D p = new Vector3D();
                    p.x = Double.parseDouble(tokens[3]) * scale;
                    p.y = Double.parseDouble(tokens[1]) * scale;
                    p.z = Double.parseDouble(tokens[2]) * scale;
                    points.add(p);
                    
                    if(p.z < config.minz)
                        config.minz = p.z;
                    
                } else if(tokens[0].equals("f")) {
                    // faces
                    
                    if(tokens.length == 4) {
                        // TriFace
                        
                        String[] facetokens1 = tokens[1].split("/");
                        String[] facetokens2 = tokens[2].split("/");
                        String[] facetokens3 = tokens[3].split("/");
                        
                        Face f = new Face();
                        f.material = currentmat;
                        Vector3D p1, p2, p3;
                        p1 = (Vector3D)points.get(Integer.parseInt(facetokens1[0]) - 1);
                        p2 = (Vector3D)points.get(Integer.parseInt(facetokens2[0]) - 1);
                        p3 = (Vector3D)points.get(Integer.parseInt(facetokens3[0]) - 1);
                        
                        f.setPoints(p1, p2, p3);
                        if(f.getXYangle() >= 90.0)
                            config.simpleterrain = false;
                        
                        faces.add(f);
                        
                    } else if(tokens.length == 5) {
                        // QuadFace
                        String[] facetokens1 = tokens[1].split("/");
                        String[] facetokens2 = tokens[2].split("/");
                        String[] facetokens3 = tokens[3].split("/");
                        String[] facetokens4 = tokens[4].split("/");
                        
                        Vector3D p1, p2, p3;
                        
                        Face f1 = new Face();
                        f1.material = currentmat;
                        p1 = (Vector3D)points.get(Integer.parseInt(facetokens1[0]) - 1);
                        p2 = (Vector3D)points.get(Integer.parseInt(facetokens2[0]) - 1);
                        p3 = (Vector3D)points.get(Integer.parseInt(facetokens3[0]) - 1);
                        f1.setPoints(p1, p2, p3);
                        
                        if(f1.getXYangle() >= 90.0)
                            config.simpleterrain = false;
                        
                        faces.add(f1);
                        
                        Face f2 = new Face();
                        f2.material = currentmat;
                        p1 = (Vector3D)points.get(Integer.parseInt(facetokens1[0]) - 1);
                        p2 = (Vector3D)points.get(Integer.parseInt(facetokens3[0]) - 1);
                        p3 = (Vector3D)points.get(Integer.parseInt(facetokens4[0]) - 1);
                        f2.setPoints(p1, p2, p3);
                        
                        if(f2.getXYangle() >= 90.0)
                            config.simpleterrain = false;
                        
                        faces.add(f2);
                    }
                } else if(tokens[0].equals("usemtl")) {
                    //change material
                    
                    currentmat = tokens[1];
                }
            }
            
        }
        
        System.out.println("Read points: " + points.size() + " Read faces: " + faces.size());
        
    }
    
    public void writeMap() {
        if(faces == null) return;
        
        PrintWriter out = null;
        try {
            out = new PrintWriter(new FileWriter(config.mapfile));
        } catch(Exception e) {
            System.err.println("Can't open output file?!");
            return;
        }
        
        out.print("{\n\"classname\" \"worldspawn\"\n");
        
        for(int i = 0; i < faces.size(); i++) {
            Face f = (Face)faces.get(i);
            out.print(f.generateBrush());
        }
        
        out.print("}\n");
        out.flush();
        out.close();
    }
    
    
    private class Vector3D {
        public double x, y, z;
        
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
            return Math.sqrt((x*x) + (y*y) + (z*z));
        }
        
        public void normalize() {
            double l = length();
            
            x /= l;
            y /= l;
            z /= l;
        }
        
    }
    
    
    private class Face {
        private Vector3D p1, p2, p3, normal;
        private double angle_xy = 0.0;
        public String material;
        
        public void setPoints(Vector3D p1, Vector3D p2, Vector3D p3) {
            this.p1 = p1;
            this.p2 = p2;
            this.p3 = p3;
            
            computeNormal();
            computeXYangle();
        }
        
        public double getXYangle() {
            return angle_xy;
        }
        
        private void computeNormal() {
            Vector3D vector1 = p1.substract(p2);
            Vector3D vector2 = p1.substract(p3);
            
            normal = vector1.crossproduct(vector2);
            normal.normalize();
        }
        
        private void computeXYangle() {
            Vector3D normal_xy = new Vector3D(0.0, 0.0, 1.0);
            angle_xy = Math.acos(normal.dotproduct(normal_xy)) / (2 * Math.PI) * 360.0;
        }
        
        public String generateBrush() {
            String result = "{\n";
            
            // this looks like a floor, extrude along the z-axis
            if(angle_xy < 70.0) {
                normal.x = 0.0;
                normal.y = 0.0;
                normal.z = 1.0;
            }
            
            normal.scale(config.brush_thickness);
            
            Vector3D p1_, p2_, p3_;
            
            if(!config.simpleterrain) {
                p1_ = p1.substract(normal);
                p2_ = p2.substract(normal);
                p3_ = p3.substract(normal);
            } else {
                double min = config.minz;
                min -= 16.0;
                p1_ = new Vector3D(p1.x, p1.y, min);
                p2_ = new Vector3D(p2.x, p2.y, min);
                p3_ = new Vector3D(p3.x, p3.y, min);
            }
            
            String mat = material;
            
            if(config.autotexturing.size() > 0) {
                double maxangle = -1.0;
                for(int i = 0; i < config.autotexturing.size(); i++) {
                    AutoTexturingEntry e = (AutoTexturingEntry)config.autotexturing.get(i);
                    if(angle_xy >= e.angle && e.angle > maxangle) {
                        mat = e.texturename;
                        maxangle = e.angle;
                    }
                }
            }
            
            // top face, apply texture here
            result += getMapPlaneString(p3, p2, p1, mat);
            
            // bottom face
            result += getMapPlaneString(p1_, p2_, p3_, "common/caulk");
            
            // extruded side 1
            result += getMapPlaneString(p1, p1_, p3_, "common/caulk");
            
            // extruded side 2
            result += getMapPlaneString(p2, p3, p3_, "common/caulk");
            
            // extruded side 3
            result += getMapPlaneString(p1, p2, p2_, "common/caulk");
            
            result += "}\n";
            
            return result;
        }
        
        
        private String getMapPlaneString(Vector3D p1, Vector3D p2, Vector3D p3, String material) {
            int flag;
            if(config.detail)
                flag = 134217728;
            else
                flag = 0;
            
            return "( " + p1.x + " " + p1.y + " " + p1.z + " ) ( " + p2.x + " " + p2.y + " " + p2.z + " ) ( " + p3.x + " " + p3.y + " " + p3.z + " ) " + material + " 0 0 0 " + config.texture_scale + " " + config.texture_scale + " " + flag + " 0 0\n";
        }
        
    }
    
}
