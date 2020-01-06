//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

// Xib2Nib.cpp.cpp : Defines the entry point for the console application.

#include <stdio.h>
#include <string.h>
#include <sstream>
#include <vector>
//#include <direct.h>
#include <assert.h>
#include <map>
//#include <filesystem>
#include <sys/stat.h>

#include "XIBObject.h"
#include "XIBObjectTypes.h"
#include "XIBDocument.h"
#include "NIBWriter.h"
#include "UIViewController.h"
#include "Plist.hpp"
#include "miscutils.h"
#include "versionutils.h"

#include "../WBITelemetry/WBITelemetry.h"

// These globals should only be employed when dealing with storyboard files (.storyboard)
// They are only set once when we determine that the input format is a storyboard
bool g_isStoryboard = false;
static char g_outputDirectory[4096];

bool IsStoryboardConversion() {
    return g_isStoryboard;
}

std::string GetOutputFilename(const char* filename) {
    std::string ret = std::string(g_outputDirectory) + "\\" + std::string(filename);

    return ret;
}

// convert string presentation of version to hex enctoded integer "a.b.c" > 0xaaaabbcc
static int stringToVersion(const char *str){
    int v = -1;
    std::stringstream ss(str);
    std::string s;
    std::vector<int> items;
    while (getline(ss, s, '.')) {
        items.push_back(std::stoi(s));
    }
    
    // small sanity for range checking
    if (items.size() && items[0] >= 0 && items[0] <= 0xFFFF) {
        v = items[0] << 16;
        if (items.size() > 1)
            v = (items[1] >= 0 && items[1] <= 0xFF) ? (v | items[1] << 8) : -1;
        if (v >= 0 && items.size() > 2)
            v = (items[2] >= 0 && items[2] <= 0xFF) ? (v | items[2] << 8) : -1;
    }
    
    return v;
}




static NIBWriter* WriteStoryNibToFile(const char *szFilename, XIBArray* arr, const int minDeploymentVersion) {
    FILE* fpOut = fopen(GetOutputFilename(szFilename).c_str(), "wb");
    NIBWriter* writer = new NIBWriter(fpOut, NULL, NULL);
    writer->_minimumDeploymentTarget = minDeploymentVersion;

    XIBObject* ownerProxy = writer->FindProxy("IBFilesOwner");
    if (!ownerProxy)
        ownerProxy = writer->AddProxy("IBFilesOwner");
    
    for (int i = 0; i < arr->count(); i++) {
        XIBObject* curObj = arr->objectAtIndex(i);
        
        writer->ExportObject(curObj);
        if (curObj->getAttrib("sceneMemberID")) {
            if (strcmp(curObj->getAttrib("sceneMemberID"), "viewController") == 0) {
                writer->AddOutletConnection(ownerProxy, curObj, "sceneViewController");
            }
        }
    }
    
    writer->WriteObjects();
    fclose(fpOut);
    
    return writer;
}

void ExportStoryBoardController(std::map<std::string, std::string> exportedControllers, const char* controllerId,
                                const int minDeploymentVersion) {
    char szFilename[255];
    
    XIBObject* controller = XIBObject::findReference(controllerId);
    UIViewController* uiViewController = dynamic_cast<UIViewController*>(controller);
    if (!uiViewController) {
        // object isn't really a controller
        printf("Object %s is not a controller\n", controller->stringValue());
        return;
    }
    
    const char* controllerIdentifier = uiViewController->_storyboardIdentifier;
    if (controllerIdentifier == NULL) {
        // not all viewcontrollers will have a storyboard identifier. If they don't use the controller Id for the key.
        controllerIdentifier = controllerId;
    }
    
    //  Check if we've already written out the controller
    if (exportedControllers.find(controllerIdentifier) != exportedControllers.end()) {
        return;
    }
    
    sprintf(szFilename, "%s.nib", controllerIdentifier);
    exportedControllers[controllerIdentifier] = controllerIdentifier;
    
    XIBArray* viewObjects = (XIBArray*)controller->_parent;
    
    const char *outFile = GetOutputFilename(szFilename).c_str();
    printf("Writing %s\n", outFile);
    
    if (minDeploymentVersion < 0) {
        // version is not limited compile to recent one
        NIBWriter* writer = WriteStoryNibToFile(outFile, (XIBArray*)viewObjects, DEPLOYMENT_TARGET_RECENT);
        assert(!writer->_wasLimitedByDeplymentTarget);
    } else {
        // there is limitation applied
        // compile to test file to check if there will be limitation during the run
        std::string tmp = std::string(outFile) + ".tmp";
        NIBWriter* writer = WriteStoryNibToFile(tmp.c_str(), (XIBArray*)viewObjects, minDeploymentVersion);
        if (writer->_wasLimitedByDeplymentTarget) {
            // limitation has applied, so begin plan b:
            // create dir with outFile name
            struct stat st = { 0 };
            stat(outFile, &st);
            if (!(((st.st_mode) & S_IFMT) == S_IFDIR) && _mkdir(outFile) != 0) {
                printf("Unable to create directory %s err=%d\n", outFile, errno);
                exit(-1);
                return;
            }
            
            // move tmp file to
            std::string dest = std::string(outFile) + "/runtime.nib";
            if (rename(tmp.c_str(), dest.c_str()) != 0) {
                printf("Failed to move nib to  %s/runtime.nib err=%d\n", outFile, errno);
                exit(-1);
                return;
            }
            
            // and now generate unlimited version
            dest = std::string(outFile) + "/objects-11.0+.nib";
            NIBWriter* writer = WriteStoryNibToFile(dest.c_str(), (XIBArray*)viewObjects, DEPLOYMENT_TARGET_RECENT);
            assert(!writer->_wasLimitedByDeplymentTarget);
        } else {
            // no limitations, just rename file to target
            if (rename(tmp.c_str(), outFile) != 0) {
                printf("Failed to rename nib to %s err=%d\n", outFile, errno);
                exit(-1);
                return;
            }
        }
    }
}


void ConvertStoryboard(pugi::xml_document& doc, const int minDeploymentVersion) {
    pugi::xml_node curNode = doc.first_child();

    //  Storyboard XIB file - get topmost controller, then export it
    const char* initialController = curNode.attribute("initialViewController").value();

    for (; curNode; curNode = curNode.next_sibling()) {
        if (curNode.type() == pugi::xml_node_type::node_element) {
            XIBArray* root = new XIBArray();
            root->ScanStoryObjects(curNode);
        }
    }

    XIBObject::ParseAllStoryMembers();

    // Print which XML nodes we did not handle during the parse for diagnostic purpose.
    XIBObject::getDocumentCoverage(doc);

    std::map<std::string, std::string> exportedControllers;
    for (const char* cur : UIViewController::_viewControllerNames) {
        ExportStoryBoardController(exportedControllers, cur, minDeploymentVersion);
    }

    Plist::dictionary_type viewControllerInfo;
    viewControllerInfo[std::string("UIStoryboardDesignatedEntryPointIdentifier")] = std::string(initialController);
    viewControllerInfo[std::string("UIStoryboardVersion")] = (int)1;

    Plist::dictionary_type viewControllerMappings;
    for (auto curController : exportedControllers) {
        viewControllerMappings[curController.first] = curController.second;
    }
    viewControllerInfo[std::string("UIViewControllerIdentifiersToNibNames")] = viewControllerMappings;

    printf("Writing %s\n", GetOutputFilename("Info.plist").c_str());
    Plist::writePlistBinary(GetOutputFilename("Info.plist").c_str(), viewControllerInfo);
}

NIBWriter* WriteNibToFile(const char *outFile, XIBArray* arr, const int minDeploymentVersion) {
    FILE* fpOut = fopen(outFile, "wb");
    if (!fpOut) {
        printf("Error opening %s\n", outFile);
        exit(-1);
        return NULL;
    }
    
    NIBWriter* writer = new NIBWriter(fpOut, NULL, NULL);
    writer->_minimumDeploymentTarget = minDeploymentVersion;
    for (int i = 0; i < arr->count(); i++) {
        XIBObject* curObj = arr->objectAtIndex(i);
        
        writer->ExportObject(curObj);
    }
    
    writer->WriteObjects();
    fclose(fpOut);
    
    return writer;
}

void ConvertXIB3ToNib(const char *outFile, pugi::xml_document& doc, const int minDeploymentVersion) {
    pugi::xml_node curNode = doc.first_child();

    //  XIB3 file
    XIBDocument* rootDocument = new XIBDocument(curNode);
    XIBObject::ParseAllStoryMembers();
    XIBObject::getDocumentCoverage(doc);

    XIBArray* viewObjects = rootDocument->Objects();
    if (viewObjects) {
        if (minDeploymentVersion < 0) {
            // version is not limited compile to recent one
            NIBWriter* writer = WriteNibToFile(outFile, (XIBArray*)viewObjects, DEPLOYMENT_TARGET_RECENT);
            assert(!writer->_wasLimitedByDeplymentTarget);
        } else {
            // there is limitation applied
            // compile to test file to check if there will be limitation during the run
            std::string tmp = std::string(outFile) + ".tmp";
            NIBWriter* writer = WriteNibToFile(tmp.c_str(), (XIBArray*)viewObjects, minDeploymentVersion);
            if (writer->_wasLimitedByDeplymentTarget) {
                // limitation has applied, so begin plan b:
                // create dir with outFile name
                struct stat st = { 0 };
                stat(outFile, &st);
                if (!(((st.st_mode) & S_IFMT) == S_IFDIR) && _mkdir(outFile) != 0) {
                    printf("Unable to create directory %s err=%d\n", outFile, errno);
                    exit(-1);
                    return;
                }
                
                // move tmp file to
                std::string dest = std::string(outFile) + "/runtime.nib";
                if (rename(tmp.c_str(), dest.c_str()) != 0) {
                    printf("Failed to move nib to  %s/runtime.nib err=%d\n", outFile, errno);
                    exit(-1);
                    return;
                }

                // and now generate unlimited version
                dest = std::string(outFile) + "/objects-11.0+.nib";
                NIBWriter* writer = WriteNibToFile(dest.c_str(), (XIBArray*)viewObjects, DEPLOYMENT_TARGET_RECENT);
                assert(!writer->_wasLimitedByDeplymentTarget);
            } else {
                // no limitations, just rename file to target
                if (rename(tmp.c_str(), outFile) != 0) {
                    printf("Failed to rename nib to %s err=%d\n", outFile, errno);
                    exit(-1);
                    return;
                }
            }
        }
    }
}
void ConvertXIBToNib(const char *outFile, pugi::xml_document& doc) {
    pugi::xml_node dataNode = doc.first_element_by_path("/archive/data");

    XIBObject* root = new XIBObject();
    root->ScanXIBNode(dataNode);
    XIBObject::ParseAllXIBMembers();

    XIBObject* Objects = root->FindMember("IBDocument.Objects");
    XIBObject* objectRecords = Objects->FindMember("objectRecords");
    XIBDictionary* properties = (XIBDictionary*)Objects->FindMember("flattenedProperties");

    XIBObject* orderedObjects = objectRecords->FindMember("orderedObjects");

    //  Go through each ordered object to find replacements
    for (memberList::iterator cur = orderedObjects->_members.begin(); cur != orderedObjects->_members.end(); cur++) {
        XIBMember* curMember = *cur;
        XIBObject* curObject = curMember->_obj;

        if (strcmp(curObject->ClassName(), "IBObjectRecord") == 0) {
            XIBObject* obj = curObject->FindMember("object");

            if (obj) {
                XIBObject* objectId = curObject->FindMember("objectID");
                if (!objectId) {
                    objectId = curObject->FindMember("id");
                }
                int objId = objectId->intValue();

                //  Attempt to find any associated custom class name
                char szPropName[255];
                sprintf(szPropName, "%d.CustomClassName", objId);

                XIBObject* customName = properties->ObjectForKey(szPropName);
                if (customName) {
                    const char* pCustomName = customName->stringValue();
                    obj->SetSwappedClassName(pCustomName);
                }

                for (memberList::iterator prop = properties->_members.begin(); prop != properties->_members.end(); prop++) {
                    char szMeta[255];
                    sprintf(szMeta, "%d.", objId);
                    if (strncmp(szMeta, (*prop)->_name, strlen(szMeta)) == 0) {
                        obj->AddMember(&(*prop)->_name[strlen(szMeta)], (*prop)->_obj);
                    }
                }
            }
        }
    }

    //  Create connections list
    XIBArray* connections = new XIBArray();
    XIBObject* connectionrecords = Objects->FindMember("connectionRecords");

    for (memberList::iterator cur = connectionrecords->_members.begin(); cur != connectionrecords->_members.end(); cur++) {
        XIBMember* curMember = *cur;
        XIBObject* curObject = curMember->_obj;

        if (strcmp(curObject->ClassName(), "IBConnectionRecord") == 0) {
            XIBObject* obj = curObject->FindMember("connection");

            if (obj) {
                connections->AddMember(NULL, obj);
            }
        }
    }

    //  Sort connection records alphabetically using stable, uh, bubble sort
    for (;;) {
        bool didSwap = false;

        for (memberList::iterator cur = connections->_members.begin(); cur != connections->_members.end(); cur++) {
            if ((cur + 1) == connections->_members.end())
                break;
            XIBMember* curMember = (*cur);
            XIBMember* nextMember = (*(cur + 1));

            if (curMember->_name != NULL)
                continue;

            //  Event connections first
            if (strcmp(curMember->_obj->_className, "IBCocoaTouchOutletConnection") == 0 &&
                strcmp(nextMember->_obj->_className, "IBCocoaTouchEventConnection") == 0) {
                *cur = nextMember;
                *(cur + 1) = curMember;
                didSwap = true;
                continue;
            }

            if (strcmp(curMember->_obj->_className, nextMember->_obj->_className) == 0) {
                const char* label1 = curMember->_obj->FindMember("label")->stringValue();
                const char* label2 = nextMember->_obj->FindMember("label")->stringValue();

                if (strcmp(label1, label2) > 0) {
                    *cur = nextMember;
                    *(cur + 1) = curMember;
                    didSwap = true;
                }
            }
        }

        if (!didSwap)
            break;
    }

    //  Construct root object
    XIBObject* rootObjects = root->FindMember("IBDocument.RootObjects");
    rootObjects->_className = "NSArray";
    connections->_className = "NSArray";

    XIBArray* allObjects = new XIBArray();
    XIBArray* accessibilityObjects = new XIBAccessibilityArray();
    XIBArray* visibleWindows = new XIBArray();

    XIBObject* nibRoot = new XIBArray();
    nibRoot->_className = "NSObject";
    nibRoot->_members.clear();
    nibRoot->AddMember("UINibTopLevelObjectsKey", rootObjects);
    nibRoot->AddMember("UINibObjectsKey", allObjects);
    nibRoot->AddMember("UINibConnectionsKey", connections);
    nibRoot->AddMember("UINibVisibleWindowsKey", visibleWindows);
    nibRoot->AddMember("UINibAccessibilityConfigurationsKey", accessibilityObjects);
    nibRoot->AddMember("UINibKeyValuePairsKey", new XIBArray());

    FILE* fpOut = fopen(outFile, "wb");
    if (!fpOut) {
        printf("Error opening %s\n", outFile);
        exit(-1);
        return;
    }

    NIBWriter* writer = new NIBWriter(fpOut);
    writer->_allUIObjects = allObjects;
    writer->_visibleWindows = visibleWindows;
    writer->AddOutputObject(nibRoot);
    writer->WriteData();

    fclose(fpOut);
}

void printUsageAndExit(int code) {
    printf("Usage:\n");
    printf("xib2nib [--minimum-deployment-target  version] --compile <out> <in>\n");

    TELEMETRY_FLUSH();
    exit(code);
}

int main(int argc, char* argv[]) {
    TELEMETRY_INIT(L"AIF-47606e3a-4264-4368-8f7f-ed6ec3366dca");

    if (checkTelemetryOptIn()) {
        TELEMETRY_ENABLE();
    } else {
        TELEMETRY_DISABLE();
    }

    TELEMETRY_SET_INTERNAL(isMSFTInternalMachine());
    std::string machineID = getMachineID();
    if (!machineID.empty()) {
        TELEMETRY_SET_MACHINEID(machineID.c_str());
    }

    TELEMETRY_EVENT_DATA(L"Xib2NibStart", getProductVersion().c_str());
    
    // parsing arguments
    const char *inFile = NULL;
    const char *outFile = NULL;
    int minVersion = -1;
    
    int idx = 1;
    while (idx < argc) {
        if (*argv[idx] == '-') {
            // parse argument
            if (strcmp("--compile", argv[idx]) == 0) {
                if (idx + 1 < argc) {
                    outFile = argv[idx + 1];
                    idx += 2;
                } else {
                    printf("Error missing argument after --compile\n");
                    printUsageAndExit(-1);
                    return -1;
                }
            } else if (strcmp("--minimum-deployment-target", argv[idx]) == 0) {
                if (idx + 1 < argc) {
                    minVersion = stringToVersion(argv[idx + 1]);
                    if (minVersion < 0) {
                        printf("Error invalid version argument %s\n", argv[idx + 1]);
                        printUsageAndExit(-1);
                        return -1;
                    }
                    idx += 2;
                } else {
                    printf("Error missing argument after --compile\n");
                    printUsageAndExit(-1);
                    return -1;
                }
            } else {
                printf("Error unknown parameter %s\n", argv[idx]);
                printUsageAndExit(-1);
                return -1;
            }
        } else {
            inFile = argv[idx];
            idx += 1;
        }
    }
    
    if (!inFile || !outFile) {
        printf("Error missing required parameters");
        printUsageAndExit(-1);
        return -1;
    }

    pugi::xml_document doc;
    pugi::xml_parse_result result = doc.load_file(inFile);
    if (!result) {
        printf("Error opening %s\n", inFile);
        return -1;
    }

    pugi::xml_node rootNode = doc.first_child();
    const char* type = getNodeAttrib(rootNode, "type");
    if (!type) {
        printf("Unable to find input type\n");
        return -1;
    }
    if (strcmp(rootNode.name(), "document") == 0 && strcmp(type, "com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB") == 0) {
        struct stat st = { 0 };
        stat(outFile, &st);
        if (!(((st.st_mode) & S_IFMT) == S_IFDIR) && _mkdir(outFile) != 0) {
            printf("Unable to create directory %s err=%d\n", outFile, errno);
            return -1;
        }

        g_isStoryboard = true;
        strcpy_s(g_outputDirectory, arraySize(g_outputDirectory), outFile);
        ConvertStoryboard(doc, minVersion);
    } else if (strstr(type, ".XIB") != NULL) {
        if (strcmp(rootNode.name(), "document") == 0) {
            ConvertXIB3ToNib(outFile, doc, minVersion);
        } else {
            ConvertXIBToNib(outFile, doc);
        }
    } else {
        printf("Unable to determine input type type=\"%s\"\n", type);
        TELEMETRY_FLUSH();
        return -1;
    }

    TELEMETRY_EVENT_DATA(L"Xib2NibFinish", getProductVersion().c_str());
    TELEMETRY_FLUSH();

    exit(0);
}
