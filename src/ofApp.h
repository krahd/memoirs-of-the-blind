#pragma once

#include "ofxiOS.h"
#include "ofxARKit.h"
#include "calcNormals.h"

class ofApp : public ofxiOSApp {
    
public:
    
    
    
    ofApp (ARSession * session);
    ofApp();
    ~ofApp ();
    
    void setup();
    void update();
    void draw();
    void exit();
    
    void touchDown(ofTouchEventArgs &touch);
    void touchMoved(ofTouchEventArgs &touch);
    void touchUp(ofTouchEventArgs &touch);
    void touchDoubleTap(ofTouchEventArgs &touch);
    void touchCancelled(ofTouchEventArgs &touch);
    
    void lostFocus();
    void gotFocus();
    void gotMemoryWarning();
    void deviceOrientationChanged(int newOrientation);
    
    ofTrueTypeFont font;
    
    ofCamera camera;
    
    ofImage img, imgToSave;
    
    
    // ====== AR STUFF ======== //
    ARSession * session;
    ARRef processor;
    
    ofMesh mesh;
    bool bDrawTriangles{false};
    bool bDrawNormals{false};
    bool showStatus{false};
    
    ofTrueTypeFont verandaFont;
    
    
    //From Zach ofxMeshUtils
    //ofZach/ofxMeshUtils/blob/master/src/ofxMeshUtils.cpp#L32-L58
    void calcNormals(ofMesh &mesh) {
        for( int i=0; i < mesh.getVertices().size(); i++ ) mesh.addNormal(ofPoint(0,0,0));
        
        for( int i=0; i < mesh.getIndices().size(); i+=3 ){
            const int ia = mesh.getIndices()[i];
            const int ib = mesh.getIndices()[i+1];
            const int ic = mesh.getIndices()[i+2];
            
            ofVec3f e1 = mesh.getVertices()[ia] - mesh.getVertices()[ib];
            ofVec3f e2 = mesh.getVertices()[ic] - mesh.getVertices()[ib];
            ofVec3f no = e2.cross( e1 );
            
            // depending on your clockwise / winding order, you might want to reverse the e2 / e1 above if your normals are flipped.
            
            mesh.getNormals()[ia] += no;
            mesh.getNormals()[ib] += no;
            mesh.getNormals()[ic] += no;
        }
    }
    
    ofVec3f calculateCenter(ofMeshFace *face) {
        int lastPointIndex{3};
        ofVec3f result;
        for (unsigned int i = 0; i < 3; i++){
            result += face->getVertex(i);
        }
        result /= lastPointIndex;
        return result;
    }
    
    
    const float normalSize{0.01};
    void drawFaceMeshNormals(ofMesh mesh);
    
    void printInfo();
    
    ofVec3f thirdEye;
    ofVec3f chin;
    ofVec3f faceCentre;
    
    simd_float4x4 transform;
    
    ofVec2f screenThirdEye;
    ofVec2f screenChin;
    ofVec2f screenFaceCentre;
    ofVec2f screenProjectedCentre;
    ofVec2f screenTopLeftBox;
    ofVec2f screenBottomRightBox;
    ofVec2f screenCentroid;
    
    
    
    ofVec2f offset;
    ofVec2f centre;
    
    
    
    float scaleFactor = 1;
    bool debugRedColour = false;
    
    bool savingPhotos = false;
    bool translating = true;
    bool scaling = false;
    
    
    ofImage mask;
    
    int MIN_TIME_BETWEEN_IMAGES = 2;
};
