#include "ofApp.h"
using namespace ofxARKit::common;

ofApp :: ofApp (ARSession * session){
    ARFaceTrackingConfiguration *configuration = [ARFaceTrackingConfiguration new];
    
    [session runWithConfiguration:configuration];
    
    this->session = session;
}

ofApp::ofApp(){
    
}

int tempCount = 0;
int numberTouchs = 0;

ofApp :: ~ofApp () {
}

vector <ofPrimitiveMode> primModes;
int currentPrimIndex;


void ofApp::setup() {
    ofBackground(0);
    ofSetFrameRate(60);
    ofEnableDepthTest();
    
    int fontSize = 8;
    if (ofxiOSGetOFWindow()->isRetinaSupportedOnDevice())
        fontSize *= 2;
    
    processor = ARProcessor::create(session);
    processor->setup();
    
    processor->deviceOrientationChanged(1);
    
    ofSetFrameRate(60);
    
    verandaFont.load("fonts/verdana.ttf", 30);
    
    
    // make img black
    ofFbo fbo;
    fbo.allocate(ofGetWidth(), ofGetHeight());
    fbo.begin();
    ofClear(ofColor::black);
    fbo.end();
    ofPixels pixels;
    fbo.readToPixels(pixels);
    img.setFromPixels(pixels);
    
    centre.x = ofGetWidth() / 2;
    centre.y = ofGetHeight() / 2;
    
    //1242 w
    //2688 h

    mask.load("mask2.png");
    //ofSetOrientation(OF_ORIENTATION_DEFAULT);
}


void ofApp::update(){    
    processor->update();
    processor->updateFaces();
}

void drawEachTriangle(ofMesh faceMesh) {
    ofPushStyle();
    for (auto face : faceMesh.getUniqueFaces()) {
        ofSetColor(ofColor::fromHsb(ofRandom(255), 255, 255));
        ofDrawTriangle(face.getVertex(0), face.getVertex(1), face.getVertex(2));
    }
    ofPopStyle();
}

void drawFaceCircles(ofMesh faceMesh) {
    ofPushStyle();
    ofSetColor(0, 0, 255);
    float r = 0.001f;
    auto verts = faceMesh.getVertices();
    for (int i = 0; i < verts.size(); ++i){
        if (i == tempCount) {
            ofSetColor(255, 0, 0);
            r = 0.005f;
        } else {
            ofSetColor(255, 255, 255);
            r = 0.001f;
        }
        ofDrawCircle(verts[i] * ofVec3f(1, 1, 1), r);
    }
    ofPopStyle();
}

void ofApp::drawFaceMeshNormals(ofMesh mesh) {
    vector<ofMeshFace> faces = mesh.getUniqueFaces();
    ofMeshFace face;
    ofVec3f c, n;
    ofPushStyle();
    ofSetColor(ofColor::white);
    for(unsigned int i = 0; i < faces.size(); i++){
        face = faces[i];
        c = calculateCenter(&face);
        n = face.getFaceNormal();
        ofDrawLine(c.x, c.y, c.z, c.x+n.x*normalSize, c.y+n.y*normalSize, c.z+n.z*normalSize);
    }
    ofPopStyle();
}

void ofApp::printInfo() {
    
    if (showStatus) {
        std::string status = std::string("Memoirs of the Blind\nTomas Laurenzo\nhttp://laurenzo.net");
        
        /*std::string infoString = std::string("Current mode: ") + std::string(bDrawTriangles ? "mesh triangles" : "circles");
         infoString += "\nNormals: " + std::string(bDrawNormals ? "on" : "off");
         infoString += std::string("\n\nTap right side of the screen to change drawing mode.");
         infoString += "\nTap left side of the screen to toggle normals.";
         */
        
        verandaFont.drawString(status, 10, ofGetHeight() * 0.85);
    }
}


void ofApp::draw() {
    
    ofDisableDepthTest();
    
    if (showStatus) {
        processor->draw();
    }
    
    float blinkLeft = 0;
    float blinkRight = 0;
    
    camera.begin();
    processor->setARCameraMatrices();
    
    auto size = processor->getFaces().size();
    // cout << size << endl;
    
    // get the transformation matrices
    ofxARKit::common::ARCameraMatrices cameraMatrices = processor->getCameraMatrices();
    
    ofMatrix4x4 cameraView = cameraMatrices.cameraView;
    ofMatrix4x4 cameraProjection = cameraMatrices.cameraProjection;
    
    
    for (auto & face : processor->getFaces()){ //TODO check that it works as intended when more than one face is around, we can use int faceCount to only process the first face.
                
        ofFill();
        ofMatrix4x4 faceTransform = toMat4(face.raw.transform);
        
        // get the rotation (this includes the rotation of the device itself)
        /*
         ofQuaternion rotQ = faceTransform.getRotate();
         ofVec3f rots = rotQ.getEuler();
         */
        
        ofPushMatrix();
        {
            ofMultMatrix(faceTransform);
            
            mesh.addVertices(face.vertices);
            mesh.addTexCoords(face.uvs);
            mesh.addIndices(face.indices);
            
            if (showStatus) {
                drawFaceCircles(mesh);
            }
            
            auto verts = mesh.getVertices();
            
            // calculate faceCentre and bounding cube
            faceCentre.set(0, 0, 0);
            screenTopLeftBox.set(99999, 99999);
            screenBottomRightBox.set(0, 0);
            screenProjectedCentre.set (0, 0);
            
            for (int i = 0; i < verts.size(); i++) {
                ofVec3f v = verts[i] * ofVec3f(1, 1, 1);
                faceCentre += v;
                
                // I want to calculate the centroid of the projected points, to do that, i project every point and add it to the centroid
                v = v * faceTransform;
                ofVec2f screenV;
                screenV = worldToScreen(v, cameraProjection, cameraView);
                screenV.y = ofGetHeight() - screenV.y; // ogl -> of
                screenProjectedCentre += screenV;
                
                // I want to calculate the 2d bounding box
                if (screenV.x < screenTopLeftBox.x) screenTopLeftBox.x = screenV.x;
                if (screenV.y < screenTopLeftBox.y) screenTopLeftBox.y = screenV.y;
                if (screenV.x > screenBottomRightBox.x) screenBottomRightBox.x = screenV.x;
                if (screenV.y > screenBottomRightBox.y) screenBottomRightBox.y = screenV.y;
                
            }
            
            screenProjectedCentre = screenProjectedCentre / verts.size();
            
            faceCentre = faceCentre / verts.size();
            faceCentre = faceCentre * faceTransform;
            
            thirdEye = verts[14] * ofVec3f(1, 1, 1);  // position of the third eye inside the face or respect to its normal position
            thirdEye = thirdEye * faceTransform;
            
            chin = verts[34] * ofVec3f(1, 1, 1);
            chin = chin * faceTransform;
            
            mesh.clear();
            
            blinkLeft = face.raw.blendShapes[ARBlendShapeLocationEyeBlinkLeft].floatValue;
            blinkRight = face.raw.blendShapes[ARBlendShapeLocationEyeBlinkRight].floatValue;
            
        }
        ofPopMatrix();            
    }
    
    // project three points the screen: third eye, centre, and chin
    screenThirdEye = worldToScreen(thirdEye, cameraProjection, cameraView);
    screenThirdEye.y = ofGetHeight() - screenThirdEye.y; // ogl -> of
    
    screenChin = worldToScreen(chin, cameraProjection, cameraView);
    screenChin.y = ofGetHeight() - screenChin.y; // ogl -> of
    
    screenFaceCentre = worldToScreen(faceCentre, cameraProjection, cameraView);
    screenFaceCentre.y = ofGetHeight() - screenFaceCentre.y; // ogl -> of
    
    screenCentroid = (screenTopLeftBox + screenBottomRightBox) / 2;
    
    camera.end(); // camera ends
    
    
    
    float blinkThreshold = 0.84; // TODO make it configurable HERE ADJUSTMENT SETTING CONFIGURATION BLINK BLINKING EYE CLOSURE CLOSED
    
    // TODO add that we only capture when it is facing the camera?
    bool captureImage = blinkLeft > blinkThreshold && blinkRight > blinkThreshold;
    
    //Debug
    //debugRedColour = !captureImage;x
    //captureImage = true;
    //End debug
    
    float border = 650;
    
    //captureImage = true; // debug, uncomment and it captures every frame regardless of blinking
    /*
    captureImage = captureImage && screenThirdEye.x < ofGetWidth() - border;
    captureImage = captureImage && screenThirdEye.x > border;
    captureImage = captureImage && screenThirdEye.y < ofGetHeight() - border - 200; //third eye not in the centre of the face
    captureImage = captureImage && screenThirdEye.y > border;
    */
    
    captureImage = captureImage && screenFaceCentre.x < ofGetWidth() - border;
    captureImage = captureImage && screenFaceCentre.x > border;
    captureImage = captureImage && screenFaceCentre.y < ofGetHeight() - border - 200; //third eye not in the centre of the face
    captureImage = captureImage && screenFaceCentre.y > border;
    
    captureImage = captureImage && ofGetElapsedTimef() > MIN_TIME_BETWEEN_IMAGES; // at least X seconds between blinks
    
    ofPixels pixels;
    ofFbo fbo;
    
    
    if (captureImage) { // get a new image
        ofResetElapsedTimeCounter();
        
        fbo = processor->getCameraFbo();
        fbo.readToPixels(pixels);
        img.setFromPixels(pixels);
        
        if (savingPhotos) {
            imgToSave.setFromPixels(pixels);
        }
        
        // img.mirror(true, false); // gl -> of; however it's slower so not doing it
        img.setImageType(OF_IMAGE_GRAYSCALE); //desaturate image
    }
    
    // translate the image so that the third eye is centred on the screen and draw it
    ofPushMatrix();
    {
        if(captureImage) { // only update the offset and scale if there's a new image, old image must be left alone
            offset = centre - screenCentroid;
            
            float correctDistance = 1500;
            float distance = screenThirdEye.distance(chin);
            
            scaleFactor = correctDistance / abs(distance); // TODO SCALE correctly and fix it gets off centre
            
        }
        if (translating) {
            ofTranslate(offset);
        }
        
        if (scaling) {
            ofScale(scaleFactor);
            //todo compensate the offcentred due to scaling
        }
        if (showStatus) {
            ofSetColor (255, 255, 255, 128);
        } else {
            ofSetColor(255, 255, 255);
        }
        
        if (debugRedColour) {
            ofSetColor (255, 0, 0, 255);
        }
        
        img.draw(0, ofGetHeight(), ofGetWidth(), -ofGetHeight()); // could use mirror instead but it's slower, so I use this
    }
    ofPopMatrix();
    
    if (captureImage && savingPhotos) { // if new photo and saving them… TODO change this to a flag and use the flag to save in update in the next frame, so that it's not slow like this version.
        //resize pow 2
        cout << "saving image…" << endl;
        
        // Init new width and height of image
        float newWidth = imgToSave.getWidth();
        float newHeight = imgToSave.getHeight();
        float aspectRatio = newWidth / newHeight;
        
        // Find the nearest pow of 2 of biggest image dimension (width or height)
        // and resize other dimension according to aspect ratio
        if(imgToSave.getWidth() >= imgToSave.getHeight()){
            //newWidth = pow(2, ceil(log(inputImage.getWidth())/log(2)));
            newWidth = ofNextPow2(ofGetWidth());
            newHeight = newWidth / aspectRatio;
        }
        else {
            newHeight = ofNextPow2(ofGetHeight());
            newWidth = newHeight * aspectRatio;
        }
        
        // Resize image according to new pow of 2 size
        imgToSave.resize(newWidth, newHeight);
        cout << ofxiPhoneGetDocumentsDirectory() + "memoirs_" + ofGetTimestampString()+ ".png" << endl;
        imgToSave.save(ofxiPhoneGetDocumentsDirectory() + "memoirs_" + ofGetTimestampString()+ ".png");
    }
    
    
    // draw mask on top
    ofSetColor(255, 255, 255, 255);
    //mask.draw(0, 0, ofGetWidth(), ofGetHeight());
    
    
    if (showStatus) {
        ofSetColor(255,255,255,255);
        ofDrawRectangle(500, 700,  300*blinkLeft, 20);
        ofDrawRectangle(500, 740,  300*blinkRight, 20);
        
        verandaFont.drawString("l: " + ofToString(blinkLeft) + ", r: " + ofToString(blinkRight), 500, 770);
        verandaFont.drawString("\nthirdEye.x: " + ofToString(thirdEye.x) +
                               "\nthirdEye.y: " + ofToString(thirdEye.y) +
                               "\nthirdEye.z: " + ofToString(thirdEye.z) +
                               "\n"+
                               "\nscreenThirdEye: " + ofToString(screenThirdEye.x) +
                               "\nscreenThirdEye: " + ofToString(screenThirdEye.y) +
                               "", 500, 815);
        
        // debug, draw projected third eye and face centre in blue, also bounding box
        ofSetColor(0, 0, 255, 255);
        ofDrawCircle(screenThirdEye.x, screenThirdEye.y, 10);
        
        ofSetColor(200, 0, 255, 255);
        ofDrawCircle(screenProjectedCentre.x, screenProjectedCentre.y, 10);
        
        ofSetColor(0, 255, 0, 78);
        ofDrawCircle(screenTopLeftBox.x, screenTopLeftBox.y, 10);
        ofDrawCircle(screenBottomRightBox.x, screenBottomRightBox.y, 10);
        ofDrawRectangle(screenTopLeftBox.x, screenTopLeftBox.y, screenBottomRightBox.x - screenTopLeftBox.x, screenBottomRightBox.y - screenTopLeftBox.y);
        ofFill();
        
        if (captureImage) {
            ofSetColor(255);
        }
        else {
            ofSetColor(255, 0, 0);
        }
        ofNoFill();
        ofDrawRectangle(border, border, ofGetWidth() - border - border, ofGetHeight() - border - 200 - border); // gotta substract x, y from w, h
        ofFill();
    }
    
    /*
     
     TODO:
     
     indices of the dots:
     20 top of the head
     39 leftmost head
     62 left bottom
     130 left top
     509 bottom right
     606 top right
     14 between the eyes
     46 left side left eye
     496 right side right eye
     
     What i need to do now is every frame, I get these 6 numbers and I store them in one array
     then, if blinking, I use these numbers to
        1) center the image
        2) resize the image so that it fits the agujerito
        3) potentially blur the edges of the face?
     */
    
    printInfo();
}


void ofApp::exit() {
    
}



void ofApp::touchDown(ofTouchEventArgs &touch){
    numberTouchs++;
    if (numberTouchs == 5) {
        showStatus = !showStatus;
    }
}


void ofApp::touchMoved(ofTouchEventArgs &touch){
    
    if (touch.x > ofGetWidth() * 0.5)
        tempCount++;
    else
        tempCount--;
    
    // cout << tempCount << endl;
    
    /*
     if (touch.x > ofGetWidth() * 0.5) {
     bDrawTriangles = !bDrawTriangles;
     
     } else if (touch.x < ofGetWidth() * 0.5) {
     bDrawNormals = !bDrawNormals;
     }
     */
}



void ofApp::touchUp(ofTouchEventArgs &touch){
    numberTouchs--;
}

void ofApp::touchDoubleTap(ofTouchEventArgs &touch){
      // showStatus = !showStatus; // TODO remove when in production, we don't want the touch to do anything
}

void ofApp::lostFocus(){}

void ofApp::gotFocus(){}

void ofApp::gotMemoryWarning(){}

void ofApp::deviceOrientationChanged(int newOrientation){
    processor->deviceOrientationChanged(newOrientation);
}

void ofApp::touchCancelled(ofTouchEventArgs& args){}

