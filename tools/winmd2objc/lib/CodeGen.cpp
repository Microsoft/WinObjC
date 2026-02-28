//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
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

#include "Precompiled.h"
#include <CodeGen.h>
#include <TypeInfo.h>
#include <Generics.h>
#include <DepResolution.h>
#include <ShimTracker.h>
#include <Misc.h>

#include <CodeGenModel.h>
#include <CommandLine.h>

using namespace std;
using namespace ObjectModel;

// ToDo: Move stuff to its own namespace.

const int namespaceLengthLimit = 200;

const wstring& g_copyrightNotice =
    L"//******************************************************************************\n"
    "//\n"
    "// Copyright (c) Microsoft. All rights reserved.\n"
    "//\n"
    "// This code is licensed under the MIT License (MIT).\n"
    "//\n"
    "// THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n"
    "// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n"
    "// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n"
    "// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n"
    "// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n"
    "// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN\n"
    "// THE SOFTWARE.\n"
    "//\n"
    "//******************************************************************************\n\n";

wstring moduleNameFromNamespace(const wstring ns) {
    return L"ObjCUWP" + replace(ns, L".", L"");
}

CommandLineOptions CommandLineInfo::_options;
wstring CommandLineInfo::_solutionName;

void CommandLineInfo::Initialize(CommandLineOptions& options, const std::wstring solutionName) {
    _options = options;
    _solutionName = solutionName;
}

bool CommandLineInfo::IsReferenceFile(const wstring& file) {
    for (auto referencedFile : _options.optMap[L"refer"]) {
        if (file == referencedFile) {
            return true;
        }
    }

    return false;
}

wstring CommandLineInfo::GetAdditionalIncludePaths() {
    wstring paths;
    for (auto path : _options.optMap[L"inc"]) {
        paths += path + L";";
    }

    return paths;
}

wstring CommandLineInfo::GetSolutionName() {
    return _solutionName;
}

namespace {
wstring _getPreprcessorDefineString(const wstring& suffix = L"") {
    wstring name = CommandLineInfo::GetSolutionName();
    replaceAll(name, L".", L"_");
    return L"IN_" + name + L"_BUILD" + suffix;
}

// Place "header" guards around the text contained in 'declaration':
inline wstring guardDeclaration(const wstring& title, const wstring& name, const wstring& declaration) {
    // clang-format off
    return formatString(
        L"// %s\n"
        L"#ifndef __%s__DEFINED\n"
        L"#define __%s__DEFINED\n"
        L"%s"
        L"#endif // __%s__DEFINED\n\n", title.c_str(), name.c_str(), name.c_str(), declaration.c_str(), name.c_str());
    // clang-format on
}

wstring filenameFromNamespace(wstring ns) {
    return replace(ns, L".", L"");
}

wstring moduleDefineFromName(wstring ns) {
    wstring temp = replace(ns, L".", L"") + L"EXPORT";
    wstring uppercase(temp.size(), 0);
    std::transform(temp.begin(), temp.end(), uppercase.begin(), ::towupper);
    return uppercase;
}

void collectSymbolDependencies(const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                               shared_ptr<ObjectModel::Symbol> sym,
                               unordered_set<wstring>& dependencies,
                               unordered_set<wstring>& referenceFileDeps,
                               map<wstring, shared_ptr<Delegate>>& delegates,
                               bool includeHeaderOnly,
                               bool isOutParam) {
    // Generics don't exist in a usable form inside the type dict. For some reason the indirected ones are better:
    if (sym->Category == WinRtGeneric) {
        auto symGeneric = dynamic_pointer_cast<ObjectModel::Generic>(sym);
        for (auto param : symGeneric->Parameters) {
            // Generic parameters are unkown if they are used as an out parameter or not. Most likely they will need to
            // be for an IVector<T>->At() or similar so just claim that they are.
            collectSymbolDependencies(types, param, dependencies, referenceFileDeps, delegates, includeHeaderOnly, true);
        }
        return;
    }

    auto symType = types.find(sym->Name);
    if (symType == types.end() || !symType->second)
        return;

    if (includeHeaderOnly || isOutParam) {
        if (CommandLineInfo::IsReferenceFile(sym->SourceFileName)) {
            // For now all our reference files generate a nuget package.
            referenceFileDeps.insert(getTypeNamespace(sym->Name));
        } else {
            dependencies.insert(getTypeNamespace(sym->Name));
        }
    }

    if (auto symCls = dynamic_pointer_cast<ObjectModel::RuntimeClass>(symType->second)) {
        for (auto iface : symCls->InterfaceImplements) {
            auto defaultAttr = iface.Attributes.find(L"Windows.Foundation.Metadata.DefaultAttribute");
            if (defaultAttr != iface.Attributes.end()) {
                auto classType = types.find(iface.Type->Name);
                if (classType != types.end()) {
                    if (includeHeaderOnly || isOutParam) {
                        // The only *true* Objective C dependency is one that requires the *creation*
                        // of a foreign class. This *only* happens as an outparam.
                        if (CommandLineInfo::IsReferenceFile(symCls->SourceFileName)) {
                            // For now all our reference files generate a nuget package.
                            referenceFileDeps.insert(getTypeNamespace(sym->Name));
                        } else {
                            dependencies.insert(getTypeNamespace(iface.Type->Name));
                        }
                    }
                }
            }
        }
    }

    if (auto del = dynamic_pointer_cast<Delegate>(symType->second)) {
        // delegate members need wrapped in a projections object so they also create a dep.
        delegates[del->Name] = del;
    }
}

void collectInterfaceDependencies(const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                                  shared_ptr<Symbol> ifaceRaw,
                                  unordered_set<wstring>& dependencies,
                                  unordered_set<wstring>& referenceFileDeps,
                                  map<wstring, shared_ptr<Delegate>>& delegates,
                                  bool includeHeaderOnly) {
    collectSymbolDependencies(types, ifaceRaw, dependencies, referenceFileDeps, delegates, includeHeaderOnly, false);

    auto iface = dynamic_pointer_cast<Interface>(ifaceRaw);
    if (!iface)
        return;

    for (const auto& subIface : iface->InterfaceImplements)
        collectInterfaceDependencies(types, subIface.Type, dependencies, referenceFileDeps, delegates, includeHeaderOnly);

    for (auto member : iface->Members) {
        for (auto param : member.second->Parameters)
            collectSymbolDependencies(types, param.Type, dependencies, referenceFileDeps, delegates, includeHeaderOnly, param.IsOutParam);
        if (!member.second->ReturnParameter.IsVoid)
            collectSymbolDependencies(types,
                                      member.second->ReturnParameter.Type,
                                      dependencies,
                                      referenceFileDeps,
                                      delegates,
                                      includeHeaderOnly,
                                      member.second->ReturnParameter.IsOutParam);
    }

    if (!includeHeaderOnly) {
        for (const auto& event : iface->Events) {
            if (event->Adder.Info) {
                const auto& adderInfo = event->Adder.Info;
                // The event is the first parameter of the adder:
                collectSymbolDependencies(
                    types, adderInfo->Parameters[0].Type, dependencies, referenceFileDeps, delegates, includeHeaderOnly, true);
            }
        }
    }
}

void collectClassDependencies(const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                              shared_ptr<RuntimeClass> cls,
                              unordered_set<wstring>& dependencies,
                              unordered_set<wstring>& referenceFileDeps,
                              map<wstring, shared_ptr<Delegate>>& delegates,
                              bool includeHeaderOnly) {
    for (auto iface : cls->InterfaceImplements) {
        auto classType = types.find(iface.Type->Name);
        if (classType != types.end()) {
            collectInterfaceDependencies(types, classType->second, dependencies, referenceFileDeps, delegates, includeHeaderOnly);
        }
    }
    auto staticAttr = cls->Attributes.find(L"Windows.Foundation.Metadata.StaticAttribute");
    if (staticAttr != cls->Attributes.end()) {
        auto classType = types.find(staticAttr->second->FixedParameters[0].StringValue);
        if (classType != types.end()) {
            auto ifaceType = dynamic_pointer_cast<ObjectModel::Interface>(classType->second);
            collectInterfaceDependencies(types, ifaceType, dependencies, referenceFileDeps, delegates, includeHeaderOnly);
        }
    }

    if (cls->Extends->Name != L"") {
        auto typeInfo = types.find(cls->Extends->Name);
        if (typeInfo != types.end()) {
            if (auto rc = dynamic_pointer_cast<RuntimeClass>(typeInfo->second)) {
                collectClassDependencies(types, rc, dependencies, referenceFileDeps, delegates, includeHeaderOnly);
            }
        }
    }
}

void collectDependenciesAndDelegatesFromNamespace(const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                                                  const shared_ptr<NameSpace>& ns,
                                                  unordered_set<wstring>& dependencies,
                                                  unordered_set<wstring>& referenceFileDeps,
                                                  map<wstring, shared_ptr<Delegate>>& delegates,
                                                  bool includeHeaderOnly) {
    for (const auto& iface : ns->Interfaces) {
        auto classType = types.find(iface->Name);
        if (classType != types.end()) {
            auto ifaceType = dynamic_pointer_cast<ObjectModel::Interface>(classType->second);
            collectInterfaceDependencies(types, ifaceType, dependencies, referenceFileDeps, delegates, includeHeaderOnly);
        }
    }

    for (const auto& cls : ns->RuntimeClasses) {
        collectClassDependencies(types, cls, dependencies, referenceFileDeps, delegates, includeHeaderOnly);
    }

    for (const auto& str : ns->Structs) {
        for (auto field : str->Fields) {
            // Structs are a bit weird. They are transformed into an ObjC class with get / set properties
            // for their public members. This means that the implementation of one needs an "OutParam" for the getters.
            // Therefore pass in true here.
            collectSymbolDependencies(types, field.ElementType, dependencies, referenceFileDeps, delegates, includeHeaderOnly, true);
        }
    }
}
}

struct ModuleNode {
    wstring name;

    // These are the namespaces on which we have dependencies.
    // This can mutate as we merge our namespaces.
    unordered_set<wstring> dependencies;

    // These are the namespaces which are part of this module.
    // The names on this list cannot mutate (additional names can be added to it but the names are always the original names),
    // it will always contain the original namespace name.
    unordered_set<shared_ptr<NameSpace>> contributors;

    bool visited;
};

vector<vector<wstring>> _buildCycleForDep(wstring current, vector<wstring> cycle, map<wstring, ModuleNode>& nodeGraph) {
    vector<vector<wstring>> toReturn{};

    if (nodeGraph[current].visited) {
        // already looked at. Return. the assumption is that a previous run as returned the cycles involving this node's subgraph.
        return toReturn;
    }

    for (unsigned int i = 0; i < cycle.size(); i++) {
        if (0 == cycle[i].compare(current)) {
            std::vector<wstring> minimalSubCycle;
            for (unsigned int j = i; j < cycle.size(); j++) {
                minimalSubCycle.push_back(cycle[j]);
            }

            toReturn.push_back(minimalSubCycle);
            return toReturn;
        }
    }

    cycle.push_back(current);

    for (const auto& dep : nodeGraph.at(current).dependencies) {
        auto subCycles = _buildCycleForDep(dep, cycle, nodeGraph);
        for (auto& subCycle : subCycles) {
            toReturn.emplace_back(std::move(subCycle));
        }
    }

    nodeGraph[current].visited = true;

    return toReturn;
}

vector<vector<wstring>> _checkForCyclesInGraph(map<wstring, ModuleNode>& nodeGraph) {
    vector<vector<wstring>> toReturn{};

    // Should be sufficient to add to a visited flag to each node. This flag indicates if the node
    // has already been fully checked for cycles. This means if it has been visited, don't waste time re checking
    // things.
    for (auto& node : nodeGraph) {
        node.second.visited = false;
    }

    // a cycle is defined to exist if starting from a node, the same node can be reached.
    for (const auto& node : nodeGraph) {
        // node is the node we are looking for a cycle for. Check all of the deps.
        for (const auto& dep : node.second.dependencies) {
            std::vector<wstring> cycle{ node.first };
            auto cycles = _buildCycleForDep(dep, cycle, nodeGraph);
            for (const auto& cycle : cycles) {
                toReturn.emplace_back(std::move(cycle));
            }
        }
    }

    return toReturn;
}

void _regenerateDependencies(const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                             map<wstring, ModuleNode>& nodeGraph,
                             map<wstring, wstring>& namespaceMap) {
    // To regenerate the dependencies, we walk each module, all the contributors in that module, and build up a list of their deps.
    for (auto& node : nodeGraph) {
        unordered_set<wstring> deps;

        unordered_set<wstring> namespaceDeps;
        unordered_set<wstring> referenceFileDeps;

        map<wstring, shared_ptr<Delegate>> delegates;
        for (const auto& ns : node.second.contributors) {
            collectDependenciesAndDelegatesFromNamespace(types, ns, namespaceDeps, referenceFileDeps, delegates, false);
        }

        unordered_set<wstring> moduleDeps;

        for (const auto& dep : namespaceDeps) {
            // Have we added the module already?
            auto iter = namespaceMap.find(dep);
            assert(iter != namespaceMap.end());
            if (0 != iter->second.compare(node.first)) {
                moduleDeps.emplace(iter->second);
            }
        }

        node.second.dependencies = std::move(moduleDeps);
    }
}

void _fixupDependencies(const wstring& newModuleName,
                        const vector<wstring>& replacedModuleNames,
                        map<wstring, ModuleNode>& nodeGraph,
                        map<wstring, wstring>& namespaceMap) {
    // Simpler case than a total regen. When a module(s) is removed and combined into a new one,
    // look for deps to the old module(s) and point them to new ones.
    for (auto& node : nodeGraph) {
        unordered_set<wstring> moduleDeps;

        for (const auto& dep : node.second.dependencies) {
            // Should this one be updated?
            auto replacedIter = find(replacedModuleNames.begin(), replacedModuleNames.end(), dep);
            if (replacedIter != replacedModuleNames.end()) {
                if (0 != newModuleName.compare(node.first)) {
                    // Don't add a self dep.
                    moduleDeps.emplace(newModuleName);
                }
            } else {
                // old one just copy it over.
                moduleDeps.emplace(dep);
            }
        }

        node.second.dependencies = std::move(moduleDeps);
    }
}

wstring _buildNameForCycle(vector<wstring>& cycle) {
    static int s_consolidateCount = 0;
    static set<wstring> s_replacements;
    sort(cycle.begin(), cycle.end());

    // The naming strategy for combining cycles is as follows:
    // If a cycle member is substring of the other members (Windows.Foo, Windows.Foo.Bar, Windows.Foo.Baz),
    // use that substring.
    // If not, (Windows.Foo, Windows.Bar, Windows.Foo.Baz), combine all non (fully) substringable members
    // by appending the non substringable (partial) portions together to the substringable portion.
    // i.e. Windows.Foo.Bar would be the result.

    // First up, see if any member is a substring of the rest.
    std::vector<wstring> uniqueStrings;
    for (const auto& module : cycle) {
        auto it = s_replacements.find(module);
        if (it != s_replacements.end()) {
            // One of the modules in the cycle had its name truncated.
            // Other modules are being merged into it so we just return the replaced name.
            return *it;
        }

        bool isSubstring = true;
        bool isUnique = false;
        for (const auto& otherModule : cycle) {
            bool match = (0 == module.compare(0, module.length(), otherModule, 0, module.length()));
            isSubstring &= match;
            isUnique |= (!match && (module.data() != otherModule.data()));
        }

        if (isSubstring) {
            return module;
        }

        if (isUnique) {
            uniqueStrings.push_back(module);
        }
    }

    // Well this means we need to deal with the unique strings and combine them.
    // First on this odessey is to find the biggest matching substring of the unique strings
    bool substringOfAll = false;
    auto locationOfLastPeriod = uniqueStrings[0].length() + 1;

    while (!substringOfAll && locationOfLastPeriod != wstring::npos) {
        locationOfLastPeriod = uniqueStrings[0].find_last_of(L'.', locationOfLastPeriod - 1);
        substringOfAll = true;
        for (const auto& otherModule : cycle) {
            bool match = (0 == uniqueStrings[0].compare(0, locationOfLastPeriod, otherModule, 0, locationOfLastPeriod));
            substringOfAll &= match;
        }
    }

    wstring toReturn = uniqueStrings[0].substr(0, locationOfLastPeriod);
    for (const auto& module : uniqueStrings) {
        toReturn += module.substr(locationOfLastPeriod);
    }

    // If the name is too big replace it with something more manageable.
    if (toReturn.length() > namespaceLengthLimit) {
        size_t pos = toReturn.find_first_of(L".");
        if (pos == toReturn.npos) {
            wprintf(L"Invalid namespace name found");
            exit(-1);
        }

        wstring replacement = toReturn.substr(0, pos + 1) + L"ConsolidatedNamespace";
        if (s_consolidateCount > 0) {
            replacement += to_wstring(s_consolidateCount);
        }
        s_consolidateCount++;
        s_replacements.insert(replacement);
        return replacement;
    }

    return toReturn;
}

void _fixBestCycle(vector<vector<wstring>>& cycles, map<wstring, ModuleNode>& nodeGraph, map<wstring, wstring>& namespaceMap) {
    // The "best" cycles will be defined as the shortest cycles where the names "are easiest to combine".
    vector<std::vector<wstring>> shortestCycles;

    size_t shortestLength = cycles[0].size();
    for (const auto& cycle : cycles) {
        if (cycle.size() < shortestLength) {
            shortestLength = cycle.size();
        }
    }

    for (const auto& cycle : cycles) {
        if (cycle.size() == shortestLength) {
            shortestCycles.emplace_back(std::move(cycle));
        }
    }

    // This will contain the modified namespace name.
    // This is generated by merging the namespaces in the cycle.
    // For actual logic how this is done see _buildNameForCycle method.
    vector<wstring> shortestCyclesNames;
    for (auto& cycle : shortestCycles) {
        shortestCyclesNames.emplace_back(_buildNameForCycle(cycle));
    }

    // The best is decided here as the name with the fewest '.'s in the name.
    auto minPeriodCount = std::count(shortestCyclesNames[0].begin(), shortestCyclesNames[0].end(), L'.');
    size_t minPeriodIndex = 0;
    for (unsigned int i = 0; i < shortestCyclesNames.size(); i++) {
        auto count = std::count(shortestCyclesNames[i].begin(), shortestCyclesNames[i].end(), L'.');
        if (count < minPeriodCount) {
            minPeriodCount = count;
            minPeriodIndex = i;
        }
    }

    auto shortest = shortestCycles[minPeriodIndex];
    auto shortestName = shortestCyclesNames[minPeriodIndex];

    // Ok grabbed the shortest cycle. Combine it.
    wstring output = L"Merging Shortest Detected Cycle Into: " + shortestName + L" { ";
    for (const auto& m : shortest) {
        output += m + L", ";
    }
    output += L" } \n";
    wprintf(L"%s", output.c_str());

    ModuleNode combined{};
    combined.name = shortestName;

    // shortest contains the vector of namespaces found in the shortest cycle.
    for (const auto& module : shortest) {
        for (const auto& contributor : nodeGraph[module].contributors) {
            combined.contributors.emplace(contributor);
            namespaceMap[contributor->Name] = combined.name;
        }

        for (const auto& dep : nodeGraph[module].dependencies) {
            // Just toss in all of the deps. This will be slightly wrong
            // as it will have self deps to the old module names but that will be fixed
            // up below in the _fixupDependencies call.
            combined.dependencies.emplace(dep);
        }

        nodeGraph.erase(module);
    }

    nodeGraph[combined.name] = std::move(combined);

    // Some namespace names have changed.
    // e.g. Suppose Windows.System and Windows.Storage are merged into a single node with name
    // Windows.System.Storage it will necessitate updating dependencies other modules/namespaces had
    // on these merged namespaces, i.e. they should now have a dependency on the merged module Windows.System.Storage.
    _fixupDependencies(shortestName, shortest, nodeGraph, namespaceMap);
}

void _mergeNodes(map<wstring, ModuleNode>& nodeGraph, map<wstring, wstring>& namespaceMap) {
    vector<vector<wstring>> arrayOfNodesToMerge;
    vector<wstring> nodesInGraph;
    // Grab all nodes from nodeGraph
    for (const auto& node : nodeGraph) {
        nodesInGraph.push_back(node.first);
    }

    arrayOfNodesToMerge.push_back(nodesInGraph);

    _fixBestCycle(arrayOfNodesToMerge, nodeGraph, namespaceMap);
}

// Returns a graph of the modules and their dependencies.
// This is in the form of pair<moduleMap, namespaceMap>
//     moduleMap - mapping of module name to a moduleDescription (pair<wstring, vector<shared_ptr<NameSpace>>>)
//                 moduleDescription - name and list of namespaces contributing to the module
//     namespaceMap - reverse lookup map of namespace to module name
pair<map<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>, map<wstring, wstring>> generateModuleGraph(
    const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
    const map<wstring, shared_ptr<NameSpace>>& convertedNamespaces,
    bool merge) {
    // Start by building a graph with everything seperated as much as possible. This known to be the worst case (most chance for
    // circular deps). Work towards a known solution (all globbed together) by checking for cycles, merging them (somewhat intelligently),
    // and then trying again. This will result in probably more modules than an "ideal" solution
    // but the heuristic of when to stop would be more difficult to determine.

    // Maps the actual namespace name to the generated merged namespace name (the name generated after resolving cycles).
    map<wstring, wstring> namespaceMap;

    // Maps generated merged namespace name to moduleName structure.
    map<wstring, ModuleNode> nodeGraph;

    wprintf(L"Creating Module Graph ... \n");

    // Start with each namespace as a separate node in our node graph.
    for (const auto& ns : convertedNamespaces) {
        nodeGraph[ns.first] = { ns.first, {}, { ns.second } };
        namespaceMap[ns.first] = ns.first;
    }

    // For each node in our nodeGraph try to get the dependencies for each of the types(interfaces, delegates etc.) in the namespace
    // represented by the node.
    _regenerateDependencies(types, nodeGraph, namespaceMap);

    auto cycles = _checkForCyclesInGraph(nodeGraph);
    while (cycles.size() > 0) {
        // nodeGraph after this call will contain a single node for all the nodes in a cycle.
        // The original nodes (from the cycle) will be deleted from nodeGraph.
        _fixBestCycle(cycles, nodeGraph, namespaceMap);
        cycles = _checkForCyclesInGraph(nodeGraph);
    }

    pair<map<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>, map<wstring, wstring>> toReturn{};
    for (const auto& node : nodeGraph) {
        pair<wstring, std::vector<shared_ptr<NameSpace>>> moduleInfo{};

        moduleInfo.first = getGUIDAsString();
        for (const auto& ns : node.second.contributors) {
            moduleInfo.second.push_back(ns);
        }

        toReturn.first.emplace(moduleNameFromNamespace(node.first), std::move(moduleInfo));
    }

    for (const auto& ns : namespaceMap) {
        toReturn.second.emplace(ns.first, moduleNameFromNamespace(ns.second));
    }

    return toReturn;
}

// This is the name of the factory method we use to instantiate the WinRT classes in the projections.
// It was originally create but that conflicted with a lot of WinRT functions named create that returned pointers, confusing ownership.
const wstring& g_instantiatorName = L"make";

struct GeneratorVisitor : public Visitor {
    const map<wstring, shared_ptr<ObjectModel::Symbol>>& _types;
    const map<wstring, wstring>& _namespaceMap;

    wstring _outDir;

    ShimTracker _shims;

    GeneratorVisitor(map<wstring, shared_ptr<ObjectModel::Symbol>>& types, wstring outDir, map<wstring, wstring>& namespaceMap)
        : _types(types), _namespaceMap(namespaceMap), _shims(namespaceMap) {
        // TODO: Unix-style director separators?
        size_t lastSlash = outDir.find_last_of(L'\\');
        if (outDir.length()) {
            if (lastSlash == wstring::npos || lastSlash != outDir.length()) {
                outDir = outDir + L"\\";
            }
        }
        _outDir = outDir;
    }

    template <typename T = Symbol>
    shared_ptr<T> resolveType(shared_ptr<Symbol> sym) const {
        if (sym->Category != UnresolvedType) {
            if (auto t = dynamic_pointer_cast<T>(sym)) {
                return t;
            }
        }
        return resolveType<T>(sym->Name);
    }

    void generateCreateWithImpl(FILE* outImpl, const wstring& interfaceName) {
        fwprintf(outImpl, L"+ (instancetype)createWith:(IInspectable*)obj {\n");
        fwprintf(outImpl, L"    ComPtr<%s> defaultInterface;\n", interfaceName.c_str());
        fwprintf(outImpl, L"    ComPtr<IInspectable> inspectableInterface(obj);\n");
        fwprintf(outImpl, L"    return SUCCEEDED(inspectableInterface.As(&defaultInterface)) ? _createRtProxy(self, obj) : nil; \n");
        fwprintf(outImpl, L"}\n\n");
    }

    template <typename T = Symbol>
    shared_ptr<T> resolveType(const wstring& name) const {
        auto it = _types.find(name);
        if (it == _types.end()) {
            return nullptr;
        }
        return dynamic_pointer_cast<T>(it->second);
    }

    wstring getPropertyAssignmentAttr(const shared_ptr<Symbol>& symbol) {
        auto ty = resolveType(symbol);

        if (ty->Category == WinRtDelegate) {
            return L"(copy) ";
        }

        if ((ty->Category != WinRtFundamental && ty->Category != WinRtEnum) || ty->Category == WinRtStruct || ty->Name == L"String") {
            return L"(retain) ";
        }
        return L"";
    }

    void generateProperty(FILE* f, const shared_ptr<PropertyInfo>& info) {
        wstring propertyName = getObjCName(info->Name);
        const auto& getterInfo = info->Getter.Info;
        const auto& setterInfo = info->Setter.Info;

        // Only generate properties that have getters since objc properties cannot be write-only:
        if (getterInfo) {
            ReturnHandler handler = handleReturnType(getterInfo, _types, _shims);
            wstring returnType = handler.returnType;

            // This is a bit of an unfortunate hack to disable generating properties for complicated
            // async operations that we handle by modifying our parameters. We can't easily marshal
            // them directly since we don't give them an explicit ObjC type.
            if (returnType == L"void") {
                throw wstring(L"Cannot marshal ") + getterInfo->ReturnParameter.Type->Name;
            }

            wstring attr;
            if (!info->Setter.Info) {
                attr = L"(readonly) ";
            } else {
                attr = getPropertyAssignmentAttr(getterInfo->ReturnParameter.Type);
            }

            // Get ARC related clang annotations.
            if (handler.needsARCAnnotation) {
                wstring annotation = _getClangAnnotationsForARC(propertyName);
                if (annotation.length()) {
                    propertyName += L" " + annotation;
                }
            }

            fwprintf(f, L"@property %s%s %s", attr.c_str(), returnType.c_str(), propertyName.c_str());
        } else {
            assert(setterInfo && "A property must have a getter or a setter");
            if (setterInfo) {
                auto sig = generateSignature(setterInfo, setterInfo->IsStatic);
                fwprintf(f, L"%s", sig.c_str());
            }
        }
    }

    wstring generateSignature(const shared_ptr<MemberInfo>& info, bool isStatic, bool activator = false, bool fromComposableClass = false) {
        auto msgName = baseObjCMsgName(info);

        // If we have activators prefixed with "create", we want to rename them to start with "make" to
        // disambinguate which are constructors and which are just regular methods, since we have a lot
        // of non-instantiators starting with "create" and it was confusing.
        static auto createPrefix = wstring(L"create");
        if (activator && msgName.find(createPrefix) == 0) {
            msgName.replace(msgName.begin(), msgName.begin() + createPrefix.size(), g_instantiatorName.begin(), g_instantiatorName.end());
        }

        vector<ObjC::MethodSig::NameTypeVar> nameTypeVars;

        // Try to understand the return type, which we need to marshall into our own format:
        ReturnHandler handler = handleReturnType(info, _types, _shims);

        // Special case for when we have no parameters at all:
        if (handler.newParams.size() == 0 && info->Parameters.size() == 0) {
            return ObjC::MethodSig(isStatic, handler.returnType, msgName, handler.needsARCAnnotation).emit();
        }

        size_t maxParams = info->Parameters.size();
        if (fromComposableClass) {
            // The last two parameters are inner and outer.
            // The constructors for these classes do not expose these parameters and are handled internally.
            // This is the reason why we ignore them.
            // We have been already ignoring them in trivially constructible classes.
            maxParams -= 2;
        }
        for (size_t i = 0; i < maxParams; ++i) {
            const auto& p = info->Parameters[i];
            auto pti = winrtTypeInfo(p.Type, _types, _shims);

            CheckSupportedArrayType(p, pti);
            _shims.addref(pti);

            // First param gets a special name:
            wstring paramName = (i == 0) ? msgName : p.Name;
            wstring ptrSigil = p.IsOutParam ? L"*" : L"";

            nameTypeVars.push_back({ paramName, pti.getObjcType() + ptrSigil, p.Name });
        }

        // If we have no other parameters, we need to give some more context to the first one, so pretty up the
        // NTV for that with the message name and good capitalization:
        if (handler.newParams.size() > 0 && nameTypeVars.empty()) {
            auto& name = handler.newParams[0].name;
            name[0] = toupper(name[0]);
            name = msgName + L"With" + name;
        }

        nameTypeVars.insert(nameTypeVars.end(), handler.newParams.begin(), handler.newParams.end());

        return ObjC::MethodSig(isStatic, handler.returnType, nameTypeVars, handler.needsARCAnnotation).emit();
    }

    enum class GenerateMode { Impl, Interface };

    template <typename RuntimeClassOrInterface>
    shared_ptr<Generic> getCollectionClassFromInterfaces(const shared_ptr<RuntimeClassOrInterface>& cls) {
        if (auto rc = dynamic_pointer_cast<RuntimeClass>(cls)) {
            for (const auto& m : rc->InterfaceImplements) {
                const WinrtContainerInfo& info = getContainerInfo(m.Type->Name);
                if (info.isSupportedInheritable) {
                    return dynamic_pointer_cast<Generic>(m.Type);
                }
            }
        }
        return nullptr;
    }

    template <typename RuntimeClassOrInterface>
    void generateInterfaceImplements(const shared_ptr<RuntimeClassOrInterface>& cls,
                                     GenerateMode mode,
                                     FILE* outImpl,
                                     bool overrideStatic = false) {
        set<wstring> generatedMembers;

        std::function<void(const wstring&)> genInterface = [&](const wstring& interfaceName) {
            auto iface = resolveType<Interface>(interfaceName);
            if (!iface) {
                const WinrtContainerInfo& info = getContainerInfo(interfaceName);
                if (!info.isInheritable) {
                    fwprintf(outImpl, L"// Could not find base class %s type information\n", interfaceName.c_str());
                }
                return;
            }

            wstring wrlType = midlToWrlType(interfaceName);
            for (const auto& member : iface->Members) {
                try {
                    if (!member.second->IsPublic) {
                        continue;
                    }

                    auto sig = generateSignature(member.second, overrideStatic);
                    if (generatedMembers.find(sig) == generatedMembers.end()) {
                        generatedMembers.insert(sig);
                        if (mode == GenerateMode::Impl) {
                            generateMemberImpl(member.second, false, false, wrlType, outImpl);
                        } else {
                            // Special functions get generated in the events and properties code, not here:
                            auto name = member.second->Name;
                            if (name.find(L"get_") == 0 || name.find(L"put_") == 0 || name.find(L"add_") == 0 ||
                                name.find(L"remove_") == 0 || name.find(L"set_") == 0) {
                                continue;
                            }

                            fwprintf(outImpl, L"%s;\n", sig.c_str());
                        }
                    }
                } catch (const wstring& why) {
                    fwprintf(outImpl, L"// Failed to generate member %s (%s)\n", member.second->Name.c_str(), why.c_str());
                }
            }

            for (const auto& sub : iface->InterfaceImplements) {
                genInterface(sub.Type->Name);
            }
        };

        if (auto rc = dynamic_pointer_cast<RuntimeClass>(cls)) {
            for (const auto& m : rc->InterfaceImplements) {
                genInterface(m.Type->Name);
            }
        } else {
            genInterface(cls->Name);
        }
    }

    template <typename RuntimeClassOrInterface>
    wstring getDefaultInterfaceName(const shared_ptr<RuntimeClassOrInterface> cls, FILE* outputFile) {
        wstring defaultInterfaceName = L"";
        if (cls->InterfaceImplements.size() > 0) {
            for (auto iface : cls->InterfaceImplements) {
                auto defaultAttr = iface.Attributes.find(L"Windows.Foundation.Metadata.DefaultAttribute");
                if (defaultAttr != iface.Attributes.end()) {
                    try {
                        auto typeInfo = winrtTypeInfo(iface.Type, _types, _shims);
                        defaultInterfaceName.assign(typeInfo.wrlFullName(true, true));
                    } catch (const wstring& e) {
                        // TODO 8316197: this really shouldn't be happening. *Every* runtime class should have a default interface that we
                        // should be able to do something with. As it stands, some classes simply won't have a createWith as a result and
                        // hopefully nobody needs that (and they will probably be sad anyway since the class will be broken for the same
                        // reason).
                        fwprintf(outputFile, L" // Failed to get type for default interface: %s\n", e.c_str());
                    }
                }
            }
        }
        return defaultInterfaceName;
    }

    void generateFactoryMethodsSignature(const wstring& name, FILE* outHeader, bool fromComposableClass = false) {
        if (auto iface = resolveType<Interface>(name)) {
            for (const auto& member : iface->Members) {
                try {
                    auto sig = generateSignature(member.second, true, true, fromComposableClass);
                    fwprintf(outHeader, L"%s ACTIVATOR;\n", sig.c_str());
                } catch (const wstring& why) {
                    assert(0);
                    fwprintf(outHeader, L"// Could not generate %s (%s)\n", member.second->Name.c_str(), why.c_str());
                }
            }
        }
    }

    // Generate the body of a runtimeclass or interface:
    template <typename RuntimeClassOrInterface>
    void generateInterfaceBody(bool protocol, const shared_ptr<RuntimeClassOrInterface> cls, FILE* outHeader, const wstring& exportDefine) {
        fwprintf(outHeader, L"// %s\n", cls->Name.c_str());

        auto mappedClassName = mapNamespacedType(cls->Name);

        fwprintf(outHeader, L"#ifndef __%s_DEFINED__\n", mappedClassName.c_str());
        fwprintf(outHeader, L"#define __%s_DEFINED__\n\n", mappedClassName.c_str());

        // List all protocols for the runtime class
        vector<wstring> protocols;
        for (auto ifaceRaw : cls->InterfaceImplements) {
            shared_ptr<Interface> ty = resolveType<Interface>(ifaceRaw.Type);
            if (!ty) {
                wprintf(L"Could not resolve base class %s for %s\n", ifaceRaw.Type->Name.c_str(), cls->Name.c_str());
                continue;
            }

            if (ty->IsExclusiveTo) {
                continue;
            }

            protocols.push_back(mapNamespacedType(ty->Name));
        }

        if (protocol) {
            fwprintf(outHeader, ObjC::ProtocolDecl(mappedClassName, protocols).emit().c_str());
        } else {
            // If we're generating a real class we need to figure out what it's being derived from:
            wstring parent = L"RTObject";

            if (auto realCls = dynamic_pointer_cast<RuntimeClass>(cls)) {
                if (realCls->Extends && realCls->Extends->Name != L"") {
                    parent = mapNamespacedType(realCls->Extends->Name);
                }
            }

            fwprintf(outHeader, ObjC::ClassDecl(mappedClassName, parent, exportDefine, protocols).emit().c_str());
        }

        fwprintf(outHeader, L"\n");

        bool isActivatable = false;
        for (const auto& attr : cls->Attributes) {
            if (attr.first == L"Windows.Foundation.Metadata.StaticAttribute") {
                auto className = attr.second->FixedParameters[0].StringValue;
                auto iface = resolveType<Interface>(className);
                generateInterfaceImplements(iface, GenerateMode::Interface, outHeader, true);
            }

            if (attr.first == L"Windows.Foundation.Metadata.ActivatableAttribute") {
                isActivatable = true;
            }
        }

        //
        // Find activatable attributes - these are synthesized into constructors:
        //

        bool hasDefaultCtor = false;
        for (const auto& attr : cls->Attributes) {
            if (attr.first == L"Windows.Foundation.Metadata.ComposableAttribute") {
                if (isProtectedComposableAttribute(attr.second)) {
                    continue;
                }

                if (!triviallyConstructableComposable(attr.second->FixedParameters[0].StringValue)) {
                    if (!isActivatable && !protocol) {
                        // This is a composable attribute and there is no Activatable attribute on the class,
                        // Parameterized constructors are generally handled under ActivatableAttribute, but, this
                        // attribute is missing for this class so we handle the parameterized constructors here.
                        assert(attr.second->NamedParameters.size() == 0);
                        const auto& params = attr.second->FixedParameters;
                        if (params[0].ElementType == SERIALIZATION_TYPE_TYPE) {
                            generateFactoryMethodsSignature(params[0].StringValue, outHeader, true);
                        }
                    }
                    continue;
                }

                // First element should be an interface with a CreateInstance method:
                assert(!hasDefaultCtor);
                fwprintf(outHeader, L"+ (instancetype)%s __attribute__ ((ns_returns_retained));\n", g_instantiatorName.c_str());
                hasDefaultCtor = true;
            }

            if (attr.first == L"Windows.Foundation.Metadata.ActivatableAttribute") {
                assert(attr.second->NamedParameters.size() == 0);
                const auto& params = attr.second->FixedParameters;

                if (params[0].ElementType == ELEMENT_TYPE_U4) {
                    // This is some sort of version string, but it means we can default construct:
                    assert(!hasDefaultCtor);
                    fwprintf(outHeader, L"+ (instancetype)%s __attribute__ ((ns_returns_retained));\n", g_instantiatorName.c_str());
                    hasDefaultCtor = true;
                }

                if (params[0].ElementType == SERIALIZATION_TYPE_TYPE) {
                    generateFactoryMethodsSignature(params[0].StringValue, outHeader);
                }
            }
        }

        wstring defaultInterfaceName = getDefaultInterfaceName(cls, outHeader);
        if (!protocol && !defaultInterfaceName.empty()) {
            fwprintf(outHeader, L"#if defined(__cplusplus)\n");
            fwprintf(outHeader, L"+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));\n");
            fwprintf(outHeader, L"#endif\n");
        }

        // Generate properties list first:
        for (const auto& prop : cls->Properties) {
            try {
                // Objective C doesn't have syntax for static properties so we need to create these as regular methods:
                const auto& getterInfo = prop->Getter.Info;
                const auto& setterInfo = prop->Setter.Info;

                if (!((getterInfo && getterInfo->IsPublic) || (setterInfo && setterInfo->IsPublic))) {
                    continue;
                }

                if (getterInfo && getterInfo->IsStatic) {
                    auto sig = generateSignature(getterInfo, true);
                    fwprintf(outHeader, L"%s;\n", sig.c_str());

                    if (setterInfo) {
                        auto sig = generateSignature(setterInfo, true);
                        fwprintf(outHeader, L"%s;\n", sig.c_str());
                    }
                } else {
                    generateProperty(outHeader, prop);
                    fprintf(outHeader, ";\n");
                }
            } catch (const wstring& why) {
                fwprintf(outHeader, L"// Failed to generate property %s (%s)\n", prop->Name.c_str(), why.c_str());
            }
        }

        for (const auto& e : cls->Events) {
            if (e->Adder.Info && e->Adder.Info->IsPublic) {
                const auto& adderInfo = e->Adder.Info;
                // The event is the first parameter of the adder:
                try {
                    auto eventTypeInfo = winrtTypeInfo(adderInfo->Parameters[0].Type, _types, _shims);
                    auto returnType = winrtTypeInfo(adderInfo->ReturnParameter.Type, _types, _shims);
                    fwprintf(outHeader,
                             L"%s (%s)add%sEvent:(%s)del;\n",
                             adderInfo->IsStatic ? L"+" : L"-",
                             returnType.getObjcType().c_str(),
                             e->Name.c_str(),
                             eventTypeInfo.getObjcType().c_str());
                } catch (const wstring& why) {
                    fwprintf(outHeader, L"// Could not generate %s (%s)\n", e->Adder.Info->Name.c_str(), why.c_str());
                }
            }

            if (e->Remover.Info && e->Remover.Info->IsPublic) {
                const auto& removerInfo = e->Remover.Info;
                fwprintf(outHeader,
                         L"%s (void)remove%sEvent:(EventRegistrationToken)tok;\n",
                         removerInfo->IsStatic ? L"+" : L"-",
                         e->Name.c_str());
            }
        }

        DeclState clsState;
        for (auto i : cls->InterfaceImplements) {
            HandleInheritedContainerDecl(dynamic_pointer_cast<ObjectModel::Generic>(i.Type), clsState, outHeader);
        }

        generateInterfaceImplements(cls, GenerateMode::Interface, outHeader);

        fwprintf(outHeader, L"@end\n\n");

        if (protocol) {
            if (auto iface = dynamic_pointer_cast<Interface>(cls)) {
                wstring objcName = mapNamespacedType(iface->Name);
                // Generate the backing objc class:
                fwprintf(outHeader,
                         L"%s\n@interface %s : RTObject <%s>\n@end\n\n",
                         exportDefine.c_str(),
                         objcName.c_str(),
                         objcName.c_str());
            }
        }

        fwprintf(outHeader, L"#endif // __%s_DEFINED__\n\n", mapNamespacedType(cls->Name).c_str());
    }

    void generateProtocol(const shared_ptr<Interface>& cls, FILE* outHeader, set<wstring>& emitted, const wstring& exportDefine) {
        auto protocolName = mapNamespacedType(cls->Name);

        // Protocols aren't generated for: generics, exclusive non-override interfaces and those already created:
        // Don't generate protocols for generic stuff:
        if (isGenericInterface(cls) || emitted.find(protocolName) != emitted.end() ||
            (cls->IsExclusiveTo && cls->Name.find(L"Overrides") == wstring::npos)) {
            return;
        }

        emitted.insert(protocolName);

        // Recursively generate any protocols we are extending before we generate ours:
        for (auto implIface : cls->InterfaceImplements) {
            if (auto iface = resolveType<Interface>(implIface.Type)) {
                generateProtocol(iface, outHeader, emitted, exportDefine);
            }
        }

        generateInterfaceBody(true, cls, outHeader, exportDefine);
    }

    void generateInterface(const shared_ptr<RuntimeClass> cls, FILE* outHeader, set<wstring>& emitted, const wstring& exportDefine) {
        auto interfaceName = mapNamespacedType(cls->Name);

        if (emitted.find(interfaceName) != emitted.end()) {
            return;
        }

        emitted.insert(interfaceName);

        // Make sure we generate all our protocols and base classes first:

        for (auto implIface : cls->InterfaceImplements) {
            if (auto iface = resolveType<Interface>(implIface.Type)) {
                generateProtocol(iface, outHeader, emitted, exportDefine);
            }
        }

        if (cls->Extends->Name != L"") {
            if (auto rc = resolveType<RuntimeClass>(cls->Extends)) {
                generateInterface(rc, outHeader, emitted, exportDefine);
            }
        }

        generateInterfaceBody(false, cls, outHeader, exportDefine);
    }

    bool handleOverridableAttribute(const shared_ptr<RuntimeClass> cls, FILE* outImpl) {
        auto curCls = cls;

        bool includeClassSetup = false;
        std::wstring proxyName;

        while (curCls) {
            for (const auto& iface : curCls->InterfaceImplements) {
                if (iface.Attributes.find(L"Windows.Foundation.Metadata.OverridableAttribute") != iface.Attributes.end()) {
                    auto objcName = mapNamespacedType(iface.Type->Name);
                    proxyName = objcName + L"_RtProxy";
                    includeClassSetup = true;

                    fwprintf(outImpl, L"    ComPtr<");
                    fwprintf(outImpl, proxyName.c_str());
                    fwprintf(outImpl, L"> typedOuter;\n");
                    fwprintf(outImpl, L"    if ([self conformsToProtocol:@protocol(");
                    fwprintf(outImpl, objcName.c_str());
                    fwprintf(outImpl, L")]) {\n");
                    fwprintf(outImpl, L"    typedOuter = Make<");
                    fwprintf(outImpl, proxyName.c_str());
                    fwprintf(outImpl, L">();\n");
                    fwprintf(outImpl, L"    outer = typedOuter;\n");
                    fwprintf(outImpl, L"    }\n");

                    // TODO 6814616: This currently will *only* compose the last interface. This isn't sufficient in many XAML
                    // cases.
                    // remove this break and the below break once a mechanism is decided on to fully aggregate the override classes.
                    break;
                }
            }

            curCls = resolveType<RuntimeClass>(curCls->Extends);

            if (includeClassSetup) {
                break;
            }
        }

        return includeClassSetup;
    }

    wstring marshallParameters(const shared_ptr<MemberInfo>& info, wstring& temps, wstring& footer, bool fromComposableClass = false) {
        //
        // [Header]: Marshal parameters
        //
        wstring parameters;
        size_t maxParams = info->Parameters.size();
        if (fromComposableClass) {
            // Parameters inner and outer are ignored.
            // These are handled internally as the public constructor for composable class does not expose these.
            maxParams -= 2;
        }

        for (size_t i = 0; i < maxParams; i++) {
            const auto& param = info->Parameters[i];
            auto typeInfo = winrtTypeInfo(param.Type, _types, _shims);
            if (parameters.size() > 0)
                parameters += L", ";

            auto ptype = _types.find(param.Type->Name);
            if (param.Type->Category == TypeCategory::WinRtArray) {
                bool fillArray = isFillArray(param);

                auto eltype = dynamic_pointer_cast<Array>(param.Type);
                auto elTypeInfo = winrtTypeInfo(eltype->Type, _types, _shims);
                if (!eltype)
                    throw wstring(L"Internal error processing array argument.");

                wstring sizeName = L"__" + param.Name + L"_ArrayLen";
                wstring arrName = L"__" + param.Name + L"_Array";
                wstring tempName = L"__" + param.Name + L"_IsTemp";
                wstring finalTypeName;

                if (param.IsOutParam || typeInfo.isCArray()) {
                    temps += L"    UINT32 " + sizeName + L" = ";
                    if (fillArray) {
                        temps += L"(UINT32)[" + param.Name + L" count];\n";
                    } else {
                        temps += L"0;\n";
                    }

                    if (typeInfo.isCArray() && param.IsInParam) {
                        temps += L"    bool " + tempName + L" = false;\n";
                    }
                    finalTypeName = elTypeInfo.wrlFullName();
                    temps += L"    " + finalTypeName + L"* " + arrName + L" = ";
                    if (fillArray) {
                        temps += L"(" + finalTypeName + L"*)[" + param.Name + L" ptr];\n";
                    } else {
                        temps += L"NULL;\n";
                    }
                }

                if (param.IsInParam && !fillArray) {
                    if (typeInfo.isCArray()) {
                        temps += L"    if(!ConvertToCArray<" + finalTypeName + L">(" + param.Name + L", &" + sizeName + L", &" + arrName +
                                 L", &" + tempName + L")) assert(0);\n";
                        footer += L"    if(" + tempName + L") CoTaskMemFree(" + arrName + L");\n";
                    } else {
                        assert(!"Other array input types are not supported yet.");
                    }

                    parameters += sizeName + L", " + arrName;
                } else if (fillArray) {
                    parameters += sizeName + L", " + arrName;
                } else {
                    parameters += L"&" + sizeName + L", &" + arrName;
                }
            } else {
                if (param.IsOutParam) {
                    parameters += (typeInfo.isIInspectableType() ? param.Name + L"OutUnmarshaled.GetAddressOf()" :
                                                                   L"&" + param.Name + L"OutUnmarshaled");
                } else {
                    if (typeInfo.isValueType && param.Type->PointerKind == ElementPointerKind::ByRef) {
                        // Specifically, Windows::Foundation::IGuidHelperStatics::Equals(GUID*, GUID*)
                        // takes these "value types" as pointers.

                        // Allocate a local to pass them by reference.
                        temps += L"    " + typeInfo.wrlFullName() + L" __" + param.Name + L"_temp = " +
                                 typeInfo.convertFnWrl(param.Name, false) + L";\n";
                        parameters += L"&__" + param.Name + L"_temp";
                    } else {
                        parameters += typeInfo.convertFnWrl(param.Name, false);
                    }
                }
            }
        }

        return parameters;
    }

    void generateMemberImplForComposableClass(const shared_ptr<RuntimeClass> cls,
                                              const shared_ptr<MemberInfo>& info,
                                              bool isStatic,
                                              bool retainResult,
                                              const wstring& rawClassName,
                                              FILE* outImpl) {
        auto sig = generateSignature(info, true, true, true);

        auto wrlName = midlToWrlType(rawClassName);
        auto classInfo = winrtTypeInfo(cls, _types, _shims);
        auto runtimeClassName = mapNamespacedType(cls->Name);

        fwprintf(outImpl, L"%s {\n", sig.c_str());
        fwprintf(outImpl, L"    ComPtr<%s> factory;\n", wrlName.c_str());
        fwprintf(outImpl,
                 L"    THROW_NS_IF_FAILED(ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L\"%s\").Get(), "
                 L"&factory));\n",
                 cls->Name.c_str());
        fwprintf(outImpl,
                 L"    %s instance;\n",
                 (classInfo.isIInspectableType() ? (L"ComPtr<" + classInfo.wrlFullName(true, true) + L">").c_str() :
                                                   classInfo.wrlFullName().c_str()));

        //
        // Here we need to find out if we have any inheritance and implementing subclass functions going on:
        //
        fwprintf(outImpl, L"    ComPtr<IInspectable> outer = nullptr;\n");
        fwprintf(outImpl, L"    ComPtr<IInspectable> inner = nullptr;\n");

        bool includeClassSetup = handleOverridableAttribute(cls, outImpl);

        wstring temps;
        wstring footer;
        wstring parameters = marshallParameters(info, temps, footer, true);

        // take care of our the outer and inner parameters.
        parameters += L", outer.Get(), &inner, &instance";

        if (!temps.empty()) {
            fwprintf(outImpl, L"%s\n", temps.c_str());
        }

        fwprintf(outImpl, L"    THROW_NS_IF_FAILED(factory->%s(%s));\n", info->Name.c_str(), parameters.c_str());
        std::wstring retStatement = runtimeClassName.c_str() + std::wstring(L"* ret = [_createRtProxy(self, ") +
                                    (classInfo.isIInspectableType() ? L"instance.Get()" : L"instance") + L") retain];\n";
        fwprintf(outImpl, L"    %s", retStatement.c_str());

        fwprintf(outImpl, L"    [ret setInnerInterface:inner.Get()];\n");

        if (includeClassSetup) {
            fwprintf(outImpl, L"    if (typedOuter) {\n");
            fwprintf(outImpl, L"        typedOuter->_inner = (id)ret;\n");
            fwprintf(outImpl, L"        typedOuter->SetComposableBasePointers(inner.Get());\n");
            fwprintf(outImpl, L"    }\n");
        }

        if (!footer.empty()) {
            fwprintf(outImpl, L"%s", footer.c_str());
        }

        fwprintf(outImpl, L"    return ret;\n}\n\n");
    }

    void generateMemberImpl(
        const shared_ptr<MemberInfo>& info, bool isStatic, bool retainResult, const wstring& interfaceName, FILE* outImpl) {
        // ignore constructors for now:
        if (info->IsCtor)
            return;

        ReturnHandler handler = handleReturnType(info, _types, _shims);

        auto sig = generateSignature(info, isStatic, retainResult);
        fwprintf(outImpl, L"%s {\n", sig.c_str());

        fwprintf(outImpl, handler.header.c_str());

        wstring temps;
        wstring footer;
        wstring parameters = marshallParameters(info, temps, footer);

        if (!info->ReturnParameter.IsVoid) {
            wstring unmarshalledReturnObj;
            bool isIInspectable = false;

            // The last parameter (or two) is the return type:
            bool isCArray = false;
            try {
                auto typeInfo = winrtTypeInfo(info->ReturnParameter.Type, _types, _shims);
                isCArray = typeInfo.isCArray();
                isIInspectable = typeInfo.isIInspectableType();
            } catch (const wstring& /*why*/) {
                // Getting an exception here is pretty pants, but it's happening.
                // wprintf(L"Warning -- unexpected exception getting return type info - %s\n", why.c_str());
            }

            if (isIInspectable) {
                fwprintf(outImpl, L"    ComPtr<%s> unmarshalledReturn;\n", handler.wrlBaseType.c_str());
                unmarshalledReturnObj = L"unmarshalledReturn.GetAddressOf()";
            } else {
                fwprintf(outImpl, L"    %s unmarshalledReturn;\n", handler.wrlType.c_str());
                unmarshalledReturnObj = L"&unmarshalledReturn";
            }

            if (isCArray) {
                fwprintf(outImpl, L"    UINT32 unmarshalledReturnLen = 0;\n");

                if (parameters.size() > 0)
                    parameters += L", ";
                parameters += L"&unmarshalledReturnLen, " + unmarshalledReturnObj;
            } else {
                if (parameters.size() > 0)
                    parameters += L", ";
                parameters += unmarshalledReturnObj;
            }
        }

        if (!temps.empty()) {
            fwprintf(outImpl, L"%s\n", temps.c_str());
        }

        //
        // [Call]: Call the function
        //

        if (isStatic) {
            fwprintf(outImpl, L"    auto _comInst = %s_inst();\n", interfaceName.c_str());
        } else {
            auto interfaceGetter = L"_getRtInterface";
            if (interfaceName.find(L"Overrides")) {
                interfaceGetter = L"_getInnerInterface";
            }

            fwprintf(outImpl, L"    auto _comInst = %s<%s>(self);\n", interfaceGetter, interfaceName.c_str());
        }

        // If this function is overloaded, then the WRL name of it will be the overloaded name:
        wstring fnName = info->Name;
        auto overloadAttr = info->Attributes.find(L"Windows.Foundation.Metadata.OverloadAttribute");
        if (overloadAttr != info->Attributes.end()) {
            fnName = overloadAttr->second->FixedParameters[0].StringValue;
        }

        // There is a difference in the way setter for a property in RT component is listed in winmd file.
        // For C++ the setters are prefixed with set_ and for other languages the prefix is put_.
        // winmdidl and midlrt generate code by defaulting to put_ names for the setters.
        // But object model returns set_ names from the winmd file. We need to generate code which is
        // consistent with what winmdidl and midlrt does, so we change the set_ prefix to put_.
        if (info->IsSpecialName && fnName.find(L"set_") == 0) {
            fnName = L"put_" + fnName.substr(4);
        }

        fwprintf(outImpl, L"    THROW_NS_IF_FAILED(_comInst->%s(%s));\n", fnName.c_str(), parameters.c_str());

        //
        // [Footer]: Start function footer output.
        //
        fwprintf(outImpl, L"%s", handler.footer.c_str());
        if (!footer.empty()) {
            fwprintf(outImpl, L"%s", footer.c_str());
        }

        // Marshal output values, if needed.
        for (const auto& param : info->Parameters) {
            if (param.Type->Category == TypeCategory::WinRtArray) {
                bool fillArray = isFillArray(param);
                if (param.IsOutParam && !fillArray) {
                    wstring sizeName = L"__" + param.Name + L"_ArrayLen";
                    wstring arrName = L"__" + param.Name + L"_Array";

                    auto ti = winrtTypeInfo(param.Type, _types, _shims);
                    _shims.addref(ti);

                    fwprintf(outImpl, L"    *%s = %s;\n", param.Name.c_str(), ti.toObjc->call(ti, arrName).c_str());
                }
            }
        }

        // Marshal return values
        if (handler.returnVal.size()) {
            if (retainResult)
                fwprintf(outImpl, L"    return [%s retain];\n", handler.returnVal.c_str());
            else
                fwprintf(outImpl, L"    return %s;\n", handler.returnVal.c_str());
        }

        fwprintf(outImpl, L"}\n\n");
    }

    // Returns whether or not a composable factory has a trivial constructor method modulo the outer stuff:
    bool triviallyConstructableComposable(const wstring& factoryName) const {
        if (auto factory = resolveType<Interface>(factoryName)) {
            return any_of(begin(factory->Members), end(factory->Members), [](const decltype(factory->Members)::value_type& m) {
                auto paramCount = m.second->Parameters.size();
                assert(paramCount >= 2);
                return paramCount == 2;
            });
        }

        return false;
    }

    bool isProtectedComposableAttribute(const shared_ptr<Attribute> attr) {
        // The parameters are fixed.
        // The second parameter (index 1) is always the CompositionType.
        // Sadly, windows.foundation.metadata.h does not expose these types so we have to hardcode
        // these values. We have Protected = 1, Public = 2.
        // https://msdn.microsoft.com/en-us/library/windows/apps/windows.foundation.metadata.compositiontype.aspx
        if (attr->FixedParameters.size() >= 2 && attr->FixedParameters[1].SignedIntValue == 1) {
            return true;
        }

        return false;
    }

    static wstring formatGuid(shared_ptr<Attribute> guidAttribute) {
        auto elem = [&](size_t index) {
            auto ret = guidAttribute->FixedParameters[index].SignedIntValue;
            assert(ret >= 0);
            return static_cast<unsigned long>(ret);
        };

        // clang-format off
        return formatString(L"(GUID){ 0x%x, 0x%x, 0x%x, { 0x%x,0x%x,0x%x,0x%x,0x%x,0x%x,0x%x,0x%x } }", elem(0), elem(1), elem(2),
                            elem(3), elem(4), elem(5), elem(6), elem(7), elem(8), elem(9), elem(10));
        // clang-format on
    }

    void generateFactoryMethodsImplementation(const shared_ptr<RuntimeClass> cls,
                                              const wstring& className,
                                              FILE* outImpl,
                                              FILE* cheatHeader) {
        auto iface = resolveType<Interface>(className);
        if (!iface) {
            wprintf(L"Failed to find class %s for %s\n", className.c_str(), cls->Name.c_str());
            return;
        }

        auto wrlTypeName = midlToWrlType(className);
        wstring objcName = mapNamespacedType(className);

        fwprintf(cheatHeader, L"static ComPtr<%s> %s_inst();\n", wrlTypeName.c_str(), objcName.c_str());

        fwprintf(outImpl, L"static ComPtr<%s> %s_inst() {\n", wrlTypeName.c_str(), objcName.c_str());
        fwprintf(outImpl, L"    ComPtr<%s> inst;\n", wrlTypeName.c_str());
        fwprintf(outImpl,
                 L"    "
                 L"THROW_NS_IF_FAILED(ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L\"%s\").Get(), "
                 L"&inst));\n",
                 cls->Name.c_str());
        fwprintf(outImpl, L"    return inst;\n}\n\n");

        for (const auto& member : iface->Members) {
            try {
                generateMemberImpl(member.second, true, true, objcName, outImpl);
            } catch (const wstring& why) {
                assert(0);
                fwprintf(outImpl, L"// Could not generate %s (%s)\n", member.second->Name.c_str(), why.c_str());
            }
        }
    }

    void generateFactoryMethodsImplementationForComposableClass(const shared_ptr<RuntimeClass> cls,
                                                                const wstring& className,
                                                                FILE* outImpl,
                                                                FILE* cheatHeader) {
        auto runtimeClassName = mapNamespacedType(cls->Name);
        auto wrlName = midlToWrlType(className);
        auto classInfo = winrtTypeInfo(cls, _types, _shims);
        auto runtimeClassWrlName = midlToWrlType(cls->Name);
        auto wrlTypeName = midlToWrlType(className);
        wstring objcName = mapNamespacedType(className);

        auto iface = resolveType<Interface>(className);
        if (!iface) {
            wprintf(L"Failed to find class %s for %s\n", className.c_str(), cls->Name.c_str());
            return;
        }

        for (const auto& member : iface->Members) {
            try {
                generateMemberImplForComposableClass(cls, member.second, true, true, className, outImpl);
            } catch (const wstring& why) {
                assert(0);
                fwprintf(outImpl, L"// Could not generate %s (%s)\n", member.second->Name.c_str(), why.c_str());
            }
        }
    }

    void generateRuntimeImpl(const shared_ptr<RuntimeClass> cls, FILE* outImpl, FILE* cheatHeader) {
        auto containerClassType = getCollectionClassFromInterfaces(cls);
        auto runtimeClassName = mapNamespacedType(cls->Name);
        fwprintf(outImpl, L"@implementation %s", runtimeClassName.c_str());

        if (containerClassType != nullptr) {
            if (!HandleInheritedContainerImpl(cls, containerClassType, _types, _shims, outImpl)) {
                containerClassType = nullptr;
            }
        }

        if (containerClassType == nullptr) {
            fwprintf(outImpl, L"\n\n");
        }

        wstring defaultInterfaceName = getDefaultInterfaceName(cls, outImpl);

        if (!defaultInterfaceName.empty()) {
            generateCreateWithImpl(outImpl, defaultInterfaceName);
        }

        // We need to know if the class has an ActivatableAttribute.
        // If the class is composable but does not have ActivatableAttribute then we still need
        // to generate the interface factory methods as specified by ComposableAttribute.
        bool isActivatable = false;
        for (const auto& attr : cls->Attributes) {
            if (attr.first == L"Windows.Foundation.Metadata.ActivatableAttribute") {
                isActivatable = true;
                break;
            }
        }

        //
        // Find construction-related attributes - these are synthesized into constructors:
        // Note that we expect a class can't be both composable _and_ activatable.
        //

        for (const auto& attr : cls->Attributes) {
            if (attr.first == L"Windows.Foundation.Metadata.ComposableAttribute") {
                auto rawClassName = attr.second->FixedParameters[0].StringValue;
                auto wrlName = midlToWrlType(rawClassName);
                auto classInfo = winrtTypeInfo(cls, _types, _shims);
                auto runtimeClassWrlName = midlToWrlType(cls->Name);

                if (isProtectedComposableAttribute(attr.second)) {
                    continue;
                }

                if (!triviallyConstructableComposable(rawClassName)) {
                    if (!isActivatable) {
                        const auto& params = attr.second->FixedParameters;
                        if (params[0].ElementType == SERIALIZATION_TYPE_TYPE) {
                            generateFactoryMethodsImplementationForComposableClass(cls, params[0].StringValue, outImpl, cheatHeader);
                        }
                    }
                    continue;
                }

                fwprintf(outImpl, L"+ (instancetype)%s {\n", g_instantiatorName.c_str());
                fwprintf(outImpl, L"    ComPtr<%s> factory;\n", wrlName.c_str());
                fwprintf(outImpl,
                         L"    THROW_NS_IF_FAILED(ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L\"%s\").Get(), "
                         L"&factory));\n",
                         cls->Name.c_str());
                fwprintf(outImpl,
                         L"    %s instance;\n",
                         (classInfo.isIInspectableType() ? (L"ComPtr<" + classInfo.wrlFullName(true, true) + L">").c_str() :
                                                           classInfo.wrlFullName().c_str()));

                //
                // Here we need to find out if we have any inheritance and implementing subclass functions going on:
                //

                fwprintf(outImpl, L"    ComPtr<IInspectable> outer = nullptr;\n");
                fwprintf(outImpl, L"    ComPtr<IInspectable> inner = nullptr;\n");

                bool includeClassSetup = handleOverridableAttribute(cls, outImpl);
                std::wstring retStatement = std::wstring(L"* ret = [_createRtProxy(self, ") +
                                            (classInfo.isIInspectableType() ? L"instance.Get()" : L"instance") + L") retain];\n";
                write(outImpl,
                      "    factory->CreateInstance(outer.Get(), &inner, &instance);\n",
                      "    ",
                      runtimeClassName,
                      retStatement,
                      "    [ret setInnerInterface:inner.Get()];\n");

                if (includeClassSetup) {
                    fwprintf(outImpl, L"    if (typedOuter) {\n");
                    fwprintf(outImpl, L"        typedOuter->_inner = (id)ret;\n");
                    fwprintf(outImpl, L"        typedOuter->SetComposableBasePointers(inner.Get());\n");
                    fwprintf(outImpl, L"    }\n");
                }

                write(outImpl, "    return ret;\n", "}\n\n");
            }

            if (attr.first == L"Windows.Foundation.Metadata.ActivatableAttribute") {
                const auto& params = attr.second->FixedParameters;

                if (params[0].ElementType == ELEMENT_TYPE_U4) {
                    fwprintf(outImpl, L"+ (instancetype)%s {\n", g_instantiatorName.c_str());
                    fwprintf(outImpl, L"    ComPtr<IInspectable> out;\n");
                    fwprintf(outImpl,
                             L"    LOG_IF_FAILED(Windows::Foundation::ActivateInstance(HString::MakeReference(L\"%s\").Get(), &out));\n",
                             cls->Name.c_str());
                    fwprintf(outImpl, L"    return [_createRtProxy<%s>(out.Get()) retain];\n}\n\n", mapNamespacedType(cls->Name).c_str());
                }

                if (params[0].ElementType == SERIALIZATION_TYPE_TYPE) {
                    generateFactoryMethodsImplementation(cls, params[0].StringValue, outImpl, cheatHeader);
                }
            }
        }

        //
        // Static methods come from the static attributes on the class:
        //

        for (const auto& attr : cls->Attributes) {
            if (attr.first == L"Windows.Foundation.Metadata.StaticAttribute") {
                auto className = attr.second->FixedParameters[0].StringValue;
                auto iface = resolveType<Interface>(className);
                if (!iface) {
                    wprintf(L"Failed to find static class %s for %s\n", className.c_str(), cls->Name.c_str());
                    continue;
                }

                auto wrlType = midlToWrlType(className);
                wstring objcName = mapNamespacedType(className);

                fwprintf(cheatHeader, L"ComPtr<%s> %s_inst();\n", wrlType.c_str(), objcName.c_str());

                fwprintf(outImpl, L"ComPtr<%s> %s_inst() {\n", wrlType.c_str(), objcName.c_str());
                fwprintf(outImpl, L"    ComPtr<%s> inst;\n", wrlType.c_str());
                fwprintf(outImpl,
                         L"    THROW_NS_IF_FAILED(ABI::Windows::Foundation::GetActivationFactory(HString::MakeReference(L\"%s\").Get(), "
                         L"&inst));\n",
                         cls->Name.c_str());
                fwprintf(outImpl, L"    return inst;\n}\n\n");

                for (const auto& member : iface->Members) {
                    try {
                        generateMemberImpl(member.second, true, false, objcName, outImpl);
                    } catch (const wstring& why) {
                        fwprintf(outImpl, L"// Failed to generate %s (%s)\n\n", member.second->Name.c_str(), why.c_str());
                    }
                }
            }
        }

        generateInterfaceImplements(cls, GenerateMode::Impl, outImpl);

        fwprintf(outImpl, L"@end\n\n");
    }

    template <typename RuntimeClassOrInterface>
    void generateProxyInstantiator(const shared_ptr<RuntimeClassOrInterface> cls,
                                   FILE* outImpl,
                                   FILE* cheatHeader,
                                   const wstring& exportDefine,
                                   bool isProtocol = false) {
        if (cls->Name.find(L'`') != wstring::npos)
            return;

        try {
            // If this is an exclusive interface, it doesn't need any of the backing stuff since that's created for the runtime class
            // instead:
            if (auto iface = dynamic_pointer_cast<Interface>(cls)) {
                auto wrlTypeName = midlToWrlType(iface->Name);
                wstring objcName = mapNamespacedType(iface->Name);

                if (iface->IsExclusiveTo)
                    return;

                if (!isProtocol) {
                    // Generate the backing objc class:
                    fwprintf(cheatHeader,
                             L"%s\n@interface %s : RTObject <%s>\n@end\n\n",
                             exportDefine.c_str(),
                             objcName.c_str(),
                             objcName.c_str());
                }

                fwprintf(outImpl, L"@implementation %s\n\n", objcName.c_str());
                if (isProtocol) {
                    generateCreateWithImpl(outImpl, wrlTypeName);
                }
                generateInterfaceImplements(cls, GenerateMode::Impl, outImpl, false);
                fwprintf(outImpl, L"@end\n\n");

                WinrtType typeInfo = winrtTypeInfo(cls, _types, _shims);
            }

            WinrtType typeInfo = winrtTypeInfo(cls, _types, _shims);
        } catch (const wstring& why) {
            fwprintf(cheatHeader, L" // Can't create proxy instantiator for type: %s\n\n", why.c_str());
        }
    }

    void generateEnumeration(const shared_ptr<Enum>& e, FILE* outHeader) {
        fwprintf(outHeader, L"// %s\n", e->Name.c_str());

        auto enumName = mapNamespacedType(e->Name);

        fwprintf(outHeader, L"enum _%s {\n", enumName.c_str());
        for (const auto& field : e->EnumerationLabels) {
            fwprintf(outHeader, L"    %s%s = %d,\n", enumName.c_str(), field.EnumerationName.c_str(), field.EnumerationValue);
        }
        fwprintf(outHeader, L"};\n");
        fwprintf(outHeader, L"typedef unsigned %s;\n\n", enumName.c_str());
    }

    void generateDepIncludes(const shared_ptr<NameSpace>& ns, FILE* outHeader, FILE* outImpl, FILE* cheatHeader) {
        unordered_set<wstring> headers;
        unordered_set<wstring> referenceFileDeps;

        map<wstring, shared_ptr<Delegate>> delegates;

        collectDependenciesAndDelegatesFromNamespace(_types, ns, headers, referenceFileDeps, delegates, true);

        // Files like Windows.Foundation are part of almost every SDK.
        // If this file is available from a referenced SDK, we use that and remove it from our headers set.
        unordered_set<wstring> toRemove;
        for (const auto referenceDepFile : referenceFileDeps) {
            for (const auto header : headers) {
                if (header == referenceDepFile) {
                    toRemove.insert(referenceDepFile);
                }
            }
        }

        for (const auto file : toRemove) {
            headers.erase(file);
        }

        bool wroteToHeader = false;
        for (const auto& header : headers) {
            if (header != ns->Name) {
                auto headerFilename = filenameFromNamespace(header);
                wroteToHeader = true;
                fwprintf(outHeader, L"#include \"%s.h\"\n", headerFilename.c_str());
                fwprintf(cheatHeader, L"#include \"%s_priv.h\"\n", headerFilename.c_str());
            }
        }

        for (const auto& header : referenceFileDeps) {
            auto headerFilename = filenameFromNamespace(header);
            fwprintf(outHeader, L"#include \"UWP/%s.h\"\n", headerFilename.c_str());
            fwprintf(cheatHeader, L"#include \"%s_priv.h\"\n", headerFilename.c_str());
        }

        for (const auto& del : delegates) {
            generateDelegate(del.second, outHeader);
            wroteToHeader = true;
        }

        if (wroteToHeader) {
            fwprintf(outHeader, L"\n");
        }
    }

    void generateStructure(const shared_ptr<Struct>& s, FILE* outHeader, FILE* outImpl, FILE* cheatHeader, const wstring& exportDefine) {
        auto structName = mapNamespacedType(s->Name);
        auto wrlName = midlToWrlType(s->Name);
        WinrtType typeInfo;
        if (winrtTypeInfoBasic(s->Name, &typeInfo))
            return;
        fwprintf(outHeader, L"// [struct] %s\n", s->Name.c_str());

        wstring structBuff;
        wstring structImplBuff;

        structBuff += exportDefine + L"\n@interface " + structName + L" : NSObject\n";
        structImplBuff += L"@implementation " + structName + L" {\n";
        structImplBuff += L"    " + wrlName +
                          L" structVal;\n"
                          "}\n";

        // Make it obvious we can instantiate these:
        structBuff += L"+ (instancetype)new;\n";
        structImplBuff += L"+ (instancetype)new { return [super new]; }\n";

        structImplBuff += L"+ (instancetype)createWith:(" + wrlName + L")s {\n" + L"    " + structName +
                          L"* ret = [[self new] autorelease];\n" + L"    ret->structVal = s;\n" + L"    return ret;\n" + L"}\n";
        structImplBuff += L"- (" + wrlName + L"*)internalStruct { return &structVal; }\n";

        for (const auto& field : s->Fields) {
            try {
                auto typeInfo = winrtTypeInfo(field.ElementType, _types, _shims);
                auto objcName = getObjCName(field.ElementName);

                structBuff +=
                    L"@property " + getPropertyAssignmentAttr(field.ElementType) + typeInfo.getObjcType() + L" " + objcName + L";\n";

                // Getter:
                _shims.addref(typeInfo);
                structImplBuff += L"- (" + typeInfo.getObjcType() + L")" + objcName + L" {\n" + L"    return " +
                                  typeInfo.toObjc->call(typeInfo, L"structVal." + field.ElementName) + L";\n" + L"}\n";

                // Setter:
                objcName[0] = toupper(objcName[0]);
                structImplBuff += L"- (void)set" + objcName + L":(" + typeInfo.getObjcType() + L")val {\n" + L"    structVal." +
                                  field.ElementName + L" = " + typeInfo.convertFnWrl(L"val", true) + L";\n" + L"}\n";
            } catch (const wstring& e) {
                fwprintf(outHeader, L" // Failed to generate member: %s\n", e.c_str());
            }
        }

        structBuff += L"@end\n\n";
        structImplBuff += L"@end\n";

        fwprintf(cheatHeader,
                 L"@interface %s (Internal)\n"
                 "+ (instancetype)createWith:(%s)s __attribute__ ((ns_returns_autoreleased));\n"
                 "- (%s*)internalStruct;\n"
                 "@end\n",
                 structName.c_str(),
                 wrlName.c_str(),
                 wrlName.c_str());
        fwprintf(cheatHeader,
                 L"inline %s* %s_create(%s val) { return [%s createWith:val]; }\n",
                 structName.c_str(),
                 structName.c_str(),
                 wrlName.c_str(),
                 structName.c_str());

        fwprintf(outHeader, L"%s", structBuff.c_str());
        fwprintf(outImpl, L"%s", structImplBuff.c_str());
    }

    void generateDelegate(const shared_ptr<Delegate>& d, FILE* outHeader) {
        auto invokeFinder = [](const decltype(d->Members)::value_type& member) { return member.second->Name == L"Invoke"; };

        auto invokeIter = find_if(begin(d->Members), end(d->Members), invokeFinder);
        assert(invokeIter != end(d->Members) && "Delegates must have an Invoke member!");
        assert(find_if(next(invokeIter), end(d->Members), invokeFinder) == end(d->Members) &&
               "Delegates must only have one Invoke member!");

        wstring args = addSeparators(invokeIter->second->Parameters, [&](const ParameterInfo& pi) {
            return winrtTypeInfo(pi.Type, _types, _shims).getObjcType() + L" " + pi.Name;
        });

        auto delegateName = mapNamespacedType(d->Name);
        auto guardedDecl =
            guardDeclaration(d->Name, delegateName, formatString(L"typedef void(^%s)(%s);\n", delegateName.c_str(), args.c_str()));

        fwprintf(outHeader, L"%s", guardedDecl.c_str());
    }

    void generateRtProxy(const shared_ptr<Interface>& iface, FILE* outImpl) {
        // Make sure we can actually override stuff here:
        if (iface->Name.find(L"Overrides") == wstring::npos)
            return;

        auto typeInfo = winrtTypeInfo(iface, _types, _shims);
        auto baseName = mapNamespacedType(iface->Name);
        auto className = baseName + L"_RtProxy";

        write(outImpl,
              "class ",
              className,
              " : public RuntimeClass<",
              typeInfo.wrlRawName(),
              ", ComposableBase<>> {\n",
              "    InspectableClass(L\"",
              className,
              "\", TrustLevel::BaseTrust)\n",
              "public:\n",
              "    ",
              typeInfo.getObjcType(),
              " _inner;\n");

        // Fill out params list:
        for (const auto& m : iface->Members) {
            auto msgInfo = m.second;

            wstring signatureParms, callParms;
            wstring returnBind, assignRetVal;
            wstring prefixBlock;

            try {
                for (const auto& p : m.second->Parameters) {
                    auto paramTypeInfo = winrtTypeInfo(p.Type, _types, _shims);
                    auto wrlType = paramTypeInfo.wrlFullName();
                    auto wrlParamName = p.Name + L"_in";
                    wstring objcCallParam;

                    if (p.IsOutParam) {
                        wrlType += L"*";
                        auto tempName = p.Name + L"_outparm";

                        // The prefix block is the temp variable decl so we can store it before the out-marshaling.
                        prefixBlock += L"        " + paramTypeInfo.getObjcType() + L" " + tempName + L";\n";
                        objcCallParam += L"&" + tempName;
                    } else {
                        objcCallParam += paramTypeInfo.toObjc->call(paramTypeInfo, wrlParamName);
                    }

                    // WRL override signature:
                    if (signatureParms.size())
                        signatureParms += L", ";
                    signatureParms += wrlType + L" " + wrlParamName;

                    // ObjC function call:
                    if (!callParms.empty())
                        callParms += L" " + p.Name;
                    callParms += L":" + objcCallParam;
                }

                // Last parameter in the C++ bindings is the return value:
                if (m.second->ReturnParameter.Type) {
                    if (signatureParms.size())
                        signatureParms += L", ";

                    auto returnTypeInfo = winrtTypeInfo(m.second->ReturnParameter.Type, _types, _shims);
                    signatureParms += returnTypeInfo.wrlFullName() + L"* ret";

                    returnBind = L"auto unmarshaledRet = ";
                    assignRetVal = L"*ret = " + returnTypeInfo.convertFnWrl(L"unmarshaledRet", true) + L";";
                }
            } catch (const wstring& err) {
                write(outImpl, "// Could not generate method ", m.second->Name, ": ", err, "\n");
                continue;
            }

            write(outImpl,
                  "    HRESULT STDMETHODCALLTYPE ",
                  getOverloadedName(msgInfo),
                  "(",
                  signatureParms,
                  ") override {\n",
                  prefixBlock, // prefix block has its own indent/newlines if needed
                  "        ",
                  returnBind,
                  "[_inner ",
                  baseObjCMsgName(msgInfo),
                  callParms,
                  "];\n");

            if (assignRetVal.size()) {
                fwprintf(outImpl, L"        %s\n", assignRetVal.c_str());
            }
            fwprintf(outImpl, L"        return 0;\n");
            fwprintf(outImpl, L"    }\n");
        }
        fwprintf(outImpl, L"};\n\n");
    }

    virtual void Visit(const shared_ptr<NameSpace>& ns) {
        wstring mappedName = filenameFromNamespace(ns->Name);
        wstring headerFileName = mappedName + L".h";
        wstring cheaterFileName = mappedName + L"_priv.h";
        wstring implFileName = mappedName + L".mm";
        wstring libFileName = _namespaceMap.at(ns->Name) + L".lib";
        wstring moduleDefine = moduleDefineFromName(_namespaceMap.at(ns->Name));

        FILE* outHeader = nullptr;
        FILE* cheatHeader = nullptr;
        FILE* outImpl = nullptr;
        if (_wfopen_s(&outHeader, (_outDir + headerFileName).c_str(), L"w") ||
            _wfopen_s(&cheatHeader, (_outDir + cheaterFileName).c_str(), L"w") ||
            _wfopen_s(&outImpl, (_outDir + implFileName).c_str(), L"w")) {
            wprintf(L"Unable to open output file(s) for namespace %s\n", mappedName.c_str());
            _exit(1);
        }

        for (auto f : { outHeader, cheatHeader, outImpl }) {
            fwprintf(f, L"%s", g_copyrightNotice.c_str());
        }

        fwprintf(outHeader, L"// %s\n// Generated from winmd2objc\n\n#pragma once\n\n", headerFileName.c_str());
        fwprintf(outHeader, L"#ifndef %s\n", moduleDefine.c_str());
        fwprintf(outHeader, L"#define %s __declspec(dllimport)\n", moduleDefine.c_str());
        fwprintf(outHeader, wstring(L"#ifndef " + _getPreprcessorDefineString() + L"\n").c_str());
        fwprintf(outHeader, L"#pragma comment(lib, \"%s\")\n", libFileName.c_str());
        fwprintf(outHeader, L"#endif\n");
        fwprintf(outHeader, L"#endif\n");
        fwprintf(outHeader, L"#include <UWP/InteropBase.h>\n\n");
        fwprintf(outImpl, L"// %s\n// Generated from winmd2objc\n\n", implFileName.c_str());
        fwprintf(outImpl, L"#include <COMIncludes.h>\n");
        // Unfortunately Windows.h has a macro for GetCurrentTime and WinRT has a function in WindowsUIXamlMediaAnimation called that..
        fwprintf(outImpl, L"#undef GetCurrentTime\n");
        fwprintf(outImpl, L"#include <%s.h>\n", ns->Name.c_str());
        fwprintf(outImpl, L"#include <COMIncludes_End.h>\n");
        fwprintf(outImpl, L"#include <UWP/RTHelpers.h>\n");
        fwprintf(outImpl, L"#include \"Starboard.h\"\n");
        fwprintf(cheatHeader, L"// %s\n// Forward decls for private object generation\n#pragma once\n\n", cheaterFileName.c_str());

        fwprintf(outImpl, L"#include \"%s\"\n", headerFileName.c_str());

        auto getMappedName = [](const auto& entry) { return mapNamespacedType(entry->Name); };

        // Is this a type that's not handled in a general way?
        auto normalType = [](const auto& obj) {
            WinrtType typeInfo;
            return !winrtTypeInfoBasic(obj->Name, &typeInfo);
        };

        bool emittedForwardDecls = false;
        auto emitFowardDeclList = [&](const wstring& type, const auto& collection) {
            auto decls = addSeparators(collection, getMappedName, L", ", normalType);
            if (decls.size()) {
                fwprintf(outHeader, L"%s %s;\n", type.c_str(), decls.c_str());
                emittedForwardDecls = true;
            }
        };

        emitFowardDeclList(L"@class", ns->RuntimeClasses);
        emitFowardDeclList(L"@class", ns->Structs);
        emitFowardDeclList(L"@protocol", ns->Interfaces);

        if (emittedForwardDecls) {
            fwprintf(outHeader, L"\n");
        }

        // Generate the enum definitions in the headers:
        for (const auto& e : ns->Enums) {
            if (normalType(e)) {
                generateEnumeration(e, outHeader);
            }
        }

        // Generate the proxy instantiators before the runtime classes and interfaces:

        fwprintf(outImpl, L"#include \"%s\"\n\n", cheaterFileName.c_str());

        for (const auto& cls : ns->RuntimeClasses)
            generateProxyInstantiator(cls, outImpl, cheatHeader, moduleDefine);
        for (const auto& cls : ns->Interfaces)
            generateProxyInstantiator(cls, outImpl, cheatHeader, moduleDefine, true);

        // Calculate header include dependencies
        generateDepIncludes(ns, outHeader, outImpl, cheatHeader);
        fwprintf(outHeader, L"#import <Foundation/Foundation.h>\n\n");

        // Generate the binding implementations for the runtime classes:
        for (const auto& cls : ns->RuntimeClasses) {
            generateRuntimeImpl(cls, outImpl, cheatHeader);
        }

        // Generate the struct definitions in the headers:
        for (const auto& s : ns->Structs) {
            generateStructure(s, outHeader, outImpl, cheatHeader, moduleDefine);
        }

        // todo Would it be better to just not name the types?
        for (const auto& d : ns->Delegates) {
            try {
                generateDelegate(d, outHeader);
            } catch (const wstring& e) {
                fwprintf(outHeader, L" // Could not generate delegate: %s\n", e.c_str());
            }
        }

        set<wstring> protoEmitted;

        // Generate the protocols the runtime classes implement
        for (const auto& iface : ns->Interfaces) {
            generateProtocol(iface, outHeader, protoEmitted, moduleDefine);
        }

        // Generate the header interfaces for runtime classes, and visit all types:
        for (const auto& cls : ns->RuntimeClasses) {
            generateInterface(cls, outHeader, protoEmitted, moduleDefine);
        }

        _shims.dumpAndReset(ns->Name, outHeader, outImpl, cheatHeader);

        // Generate WinRT proxies, exposing ObjC implementations of WinRT interfaces:
        for (const auto& iface : ns->Interfaces) {
            generateRtProxy(iface, cheatHeader);
        }

        fclose(outImpl);
        fclose(outHeader);
        fclose(cheatHeader);
    }
};

// Maintain a list of additional classes to be exported from ObjCUWP here.
// Better than having an external file and requiring users to provide the
// file path when compiling ObjCUWP (and not other projections).
void _getAdditionalExportedClassesForObjCUWP(vector<wstring>& exportedClasses) {
    exportedClasses.insert(exportedClasses.end(),
                           { L"WUXDoubleTappedEventHandlerObj",
                             L"WUXHoldingEventHandlerObj",
                             L"WUXKeyEventHandlerObj",
                             L"WUXManipulationCompletedEventHandlerObj",
                             L"WUXManipulationDeltaEventHandlerObj",
                             L"WUXManipulationInertiaStartingEventHandlerObj",
                             L"WUXManipulationStartedEventHandlerObj",
                             L"WUXManipulationStartingEventHandlerObj",
                             L"WUXPointerEventHandlerObj",
                             L"WUXRightTappedEventHandlerObj",
                             L"WUXTappedEventHandlerObj",
                             L"WXDragEventHandlerObj" });
}

wstring generateClangCompileStatements(const vector<shared_ptr<NameSpace>>& namespaces) {
    // clang-format off
    wstring headers = LR"~(
  <ItemGroup>
)~";
    wstring clangCompileBlock =
        LR"~(  <ItemGroup>
)~";
    for (auto& ns : namespaces) {
        headers += LR"~(    <PackageHeader Include="$(MSBuildProjectDirectory)\..\..\)~" + g_srcDirectory;
        headers += filenameFromNamespace(ns->Name);
        headers += LR"~(.h" />
)~";

        clangCompileBlock += LR"~(    <ClangCompile Include="..\..\)~" + g_srcDirectory;
        clangCompileBlock += filenameFromNamespace(ns->Name);
        clangCompileBlock += LR"~(.mm" />
)~";
    }

    headers += LR"~(  </ItemGroup>
)~";
    clangCompileBlock += LR"~(  </ItemGroup>
)~";

    // clang-format on
    return headers + clangCompileBlock;
}

wstring generateProjectReferences(const vector<shared_ptr<NameSpace>>& namespaces,
                                  const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                                  const map<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>& moduleMap,
                                  const map<wstring, wstring>& namespaceMap) {
    wstring projectReferenceBlock =
        LR"~(  <ItemGroup>
)~";
    unordered_set<wstring> addedModules;
    for (auto& ns : namespaces) {
        unordered_set<wstring> headers;
        unordered_set<wstring> referenceFileHeaders;

        map<wstring, shared_ptr<Delegate>> delegates;

        collectDependenciesAndDelegatesFromNamespace(types, ns, headers, referenceFileHeaders, delegates, false);

        for (const auto& h : headers) {
            if (namespaceMap.find(h) == namespaceMap.end() || namespaceMap.at(h).compare(namespaceMap.at(ns->Name)) == 0) {
                // This header is part of the same module as this namespace. No need to add a reference.
                continue;
            }

            if (addedModules.find(namespaceMap.at(h)) != addedModules.end()) {
                // already added this module from a different dep. Don't re-add it silly.
                continue;
            }

            addedModules.emplace(namespaceMap.at(h));

            projectReferenceBlock += LR"~(    <ProjectReference Include=")~";
            projectReferenceBlock += L"../" + namespaceMap.at(h) + L"/" + namespaceMap.at(h) + L".vcxproj";
            projectReferenceBlock +=
                LR"~(">
      <Project>)~";
            projectReferenceBlock += moduleMap.at(namespaceMap.at(h)).first; // adds in the guid for this module
            projectReferenceBlock +=
                LR"~(</Project>
    </ProjectReference>
)~";
        }
    }

    return projectReferenceBlock += LR"~(  </ItemGroup>)~";
}

wstring _getSolutionConfigurationPlatformEntriesForGUID(const wstring& projectGUID, bool forNuget = false) {
    wstring prefix;
    if (forNuget) {
        prefix = L"        " + projectGUID + L".Debug|Any CPU.ActiveCfg = Debug|Any CPU\n" + L"        " + projectGUID +
                 L".Debug|Any CPU.Build.0 = Debug|Any CPU\n" + L"        " + projectGUID +
                 L".Release|Any CPU.ActiveCfg = Release|Any CPU\n" + L"        " + projectGUID +
                 L".Release|Any CPU.Build.0 = Release|Any CPU\n";
    } else {
        prefix = L"        " + projectGUID + L".Debug|Any CPU.ActiveCfg = Debug|Win32\n" + L"        " + projectGUID +
                 L".Release|Any CPU.ActiveCfg = Release|Win32\n";
    }

    return prefix + L"        " + projectGUID + L".Debug|ARM.ActiveCfg = Debug|ARM\n" + L"        " + projectGUID +
           L".Debug|ARM.Build.0 = Debug|ARM\n" + L"        " + projectGUID + L".Debug|x86.ActiveCfg = Debug|Win32\n" + L"        " +
           projectGUID + L".Debug|x86.Build.0 = Debug|Win32\n" + L"        " + projectGUID + L".Release|ARM.ActiveCfg = Release|ARM\n" +
           L"        " + projectGUID + L".Release|ARM.Build.0 = Release|ARM\n" + L"        " + projectGUID +
           L".Release|x86.ActiveCfg = Release|Win32\n" + L"        " + projectGUID + L".Release|x86.Build.0 = Release|Win32\n";
}

void generateSolutionFile(const map<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>& moduleMap,
                          const wstring& outputDirectory,
                          const wstring& solutionFileName,
                          const pair<wstring, wstring>& nugetInfo) {
    const wstring slnHeader =
        L"Microsoft Visual Studio Solution File, Format Version 12.00\n"
        L"# Visual Studio 15\n"
        L"VisualStudioVersion = 15.0.26117.0\n"
        L"MinimumVisualStudioVersion = 10.0.40219.1\n";
    const wstring prefix = L"Project(\"{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}\") = ";
    const wstring suffix = L"EndProject\n";

    wstring globalSolutionConfigurationPlatforms =
        L"Global\n"
        L"    GlobalSection(SolutionConfigurationPlatforms) = preSolution\n"
        L"        Debug|Any CPU = Debug|Any CPU\n"
        L"        Debug|ARM = Debug|ARM\n"
        L"        Debug|x86 = Debug|x86\n"
        L"        Release|Any CPU = Release|Any CPU\n"
        L"        Release|ARM = Release|ARM\n"
        L"        Release|x86 = Release|x86\n"
        L"    EndGlobalSection\n"
        L"    GlobalSection(ProjectConfigurationPlatforms) = postSolution\n";

    wstring projectNameList;
    for (const auto& modulePair : moduleMap) {
        wstring projectName = modulePair.first;
        wstring projectPath = L".\\" + g_projectsDirectory + projectName + L"\\" + projectName + L".vcxproj";
        wstring projectGUID = modulePair.second.first;
        projectNameList += prefix + L"\"" + projectName + L"\", \"" + projectPath + L"\", \"" + projectGUID + L"\"\n" + suffix;

        globalSolutionConfigurationPlatforms += _getSolutionConfigurationPlatformEntriesForGUID(projectGUID);
    }

    if (nugetInfo.first.length()) {
        const wstring nugetProjectPrefix = LR"~(Project("{5DD5E4FA-CB73-4610-85AB-557B54E96AA9}") = )~";
        wstring nugetProjectPath = L".\\" + g_projectsDirectory + g_nugetProjectDirectory + L"\\" + nugetInfo.first + L".nuproj";
        projectNameList +=
            nugetProjectPrefix + L"\"" + nugetInfo.first + L"\", \"" + nugetProjectPath + L"\", \"" + nugetInfo.second + L"\"\n" + suffix;
        globalSolutionConfigurationPlatforms += _getSolutionConfigurationPlatformEntriesForGUID(nugetInfo.second, true);
    }

    globalSolutionConfigurationPlatforms +=
        L"    EndGlobalSection\n"
        L"    GlobalSection(SolutionProperties) = preSolution\n"
        L"        HideSolutionNode = FALSE\n"
        L"    EndGlobalSection\n"
        L"EndGlobal\n";

    FILE* slnFile = nullptr;
    if (_wfopen_s(&slnFile, (outputDirectory + L"\\" + solutionFileName + L".sln").c_str(), L"w")) {
        wprintf(L"Failed to open solution file\n");
        exit(1);
    }

    fwprintf(slnFile, (slnHeader + projectNameList + globalSolutionConfigurationPlatforms).c_str());

    fclose(slnFile);
}

wstring generateNugetProject(const map<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>& moduleMap,
                             const wstring& outputDirectory,
                             const wstring& nugetPackageId,
                             const wstring& solutionName) {
    // utf-8 requires the copyright symbol to be encoded as 0xC2 0XA9.
    wstring copyrightSymbol;
    copyrightSymbol.push_back(0xC2);
    copyrightSymbol.push_back(0xA9);

    wstring guidAsString = getGUIDAsString();

    // clang-format off
    wstring referenceBlock =
        LR"~(  <ItemGroup>
)~";

    for (const auto& projectInfo : moduleMap) {
        referenceBlock += LR"~(
    <ProjectReference Include=")~";
        referenceBlock += L"..\\" + projectInfo.first + L"\\" + projectInfo.first + L".vcxproj";
        referenceBlock +=
            LR"~(" />)~";
    }

    referenceBlock += LR"~(
    <PackageReference Include="Nuget.Build.Packaging" Version="0.2.3" />
    <PackageReference Include="WinObjC.Packaging" Version="*" />
)~";
    referenceBlock += LR"~(  </ItemGroup>)~";

    wstring content = LR"~(<Project ToolsVersion="14.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <Import Project="$(NuGetAuthoringPath)\NuGet.Packaging.Authoring.props" Condition="Exists('$(NuGetAuthoringPath)\NuGet.Packaging.Authoring.props')" />
  <Import Project="$(WINOBJC_SDK_ROOT)\common\winobjc.nuproj.common.props" Condition="Exists('$(WINOBJC_SDK_ROOT)\common\winobjc.nuproj.common.props')" />
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Debug|Any CPU">
      <Configuration>Debug</Configuration>
      <Platform>AnyCPU</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|Any CPU">
      <Configuration>Release</Configuration>
      <Platform>AnyCPU</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug|x86">
      <Configuration>Debug</Configuration>
      <Platform>x86</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|x86">
      <Configuration>Release</Configuration>
      <Platform>x86</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug|ARM">
      <Configuration>Debug</Configuration>
      <Platform>ARM</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|ARM">
      <Configuration>Release</Configuration>
      <Platform>ARM</Platform>
    </ProjectConfiguration>
  </ItemGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x86'" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x86'" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|ARM'" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|ARM'" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Any CPU'" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Any CPU'" />
  <PropertyGroup Label="Configuration">
    <PackageId>)~" + nugetPackageId + LR"~(</PackageId>
    <Title>)~" + nugetPackageId + LR"~(</Title>
    <Authors>Microsoft</Authors>
    <Owners>Microsoft</Owners>
    <Summary>)~" + nugetPackageId + LR"~(</Summary>
    <Description>)~" + nugetPackageId + LR"~(</Description>
    <PackageReleaseNotes>
    </PackageReleaseNotes>
    <PackageProjectUrl>
    </PackageProjectUrl>
    <PackageLicenseUrl>
    </PackageLicenseUrl>
    <Copyright>Copyright )~" + copyrightSymbol + LR"~( Microsoft</Copyright>
    <PackageTags>)~" + nugetPackageId + LR"~(</PackageTags>
    <UpdateAssemblyInfo>false</UpdateAssemblyInfo>
    <WriteVersionInfoToBuildLog>false</WriteVersionInfoToBuildLog>
    <TargetFramework>uap10.0</TargetFramework>
  </PropertyGroup>
  <PropertyGroup Label="Globals">
    <OutputPath>..\..\..\..\build\OutputPackages\$(Configuration)\</OutputPath>
    <ProjectGuid>)~" + guidAsString + LR"~(</ProjectGuid>
  </PropertyGroup>
  )~" + referenceBlock + LR"~(
  <Import Project="$(MSBuildToolsPath)\Microsoft.Common.targets" />
  <Import Project="$(NuGetAuthoringPath)\NuGet.Packaging.Authoring.targets" Condition="Exists('$(NuGetAuthoringPath)\NuGet.Packaging.Authoring.targets')" />
  <Import Project="$(WINOBJC_SDK_ROOT)\common\winobjc.nuproj.common.targets" Condition="Exists('$(WINOBJC_SDK_ROOT)\common\winobjc.nuproj.common.targets')" />
  <Import Project="$(WINOBJC_SDK_ROOT)\common\winobjc.packagereference.override.targets" Condition="Exists('$(SolutionDir)\..\common\winobjc.packagereference.override.targets')" />
</Project>)~";
    // clang-format on

    FILE* nugetProjectFile = nullptr;
    wstring nuprojFileName = outputDirectory + nugetPackageId + L".nuproj";
    if (_wfopen_s(&nugetProjectFile, nuprojFileName.c_str(), L"w")) {
        int err;
        _get_errno(&err);
        wprintf(L"Failed to open nuget project file\n");
        exit(1);
    }

    fwprintf(nugetProjectFile, content.c_str());

    fclose(nugetProjectFile);
    return guidAsString;
}

void generateVCXProj(const pair<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>& module,
                     const wstring& projectDirectoryPath,
                     const map<wstring, shared_ptr<ObjectModel::Symbol>>& types,
                     const map<wstring, pair<wstring, vector<shared_ptr<NameSpace>>>>& moduleMap,
                     const map<wstring, wstring>& namespaceMap,
                     const vector<wstring>& nugetDependencies,
                     const wstring& solutionName) {
    // We do not expect a project without any namespace info in it.
    assert(module.second.second.size() > 0);

    wstring additionalIncludePaths = CommandLineInfo::GetAdditionalIncludePaths();

    // clang-format off
    wstring packageReferences = LR"~(
  <ItemGroup>
    <PackageReference Include="Nuget.Build.Packaging" Version="0.2.3" />
    <PackageReference Include="WinObjC.Language" Version="*" />
    <PackageReference Include="WinObjC.Frameworks.UWP.Core" Version="*" />)~";
    for (auto& nugetInfo : nugetDependencies) {
        packageReferences += L"\n    ";
        packageReferences += nugetInfo;
    }
    packageReferences += LR"~(
  </ItemGroup>
)~";

    wstring vcxprojTemplate = LR"~(<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Debug|ARM">
      <Configuration>Debug</Configuration>
      <Platform>ARM</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug|Win32">
      <Configuration>Debug</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|ARM">
      <Configuration>Release</Configuration>
      <Platform>ARM</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|Win32">
      <Configuration>Release</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
  </ItemGroup>
%s
  <PropertyGroup Label="Globals">
    <ProjectGuid>%s</ProjectGuid>
    <Keyword>DynamicLibrary</Keyword>
    <ProjectName>%s</ProjectName>
    <RootNamespace>%s</RootNamespace>
    <DefaultLanguage>en-US</DefaultLanguage>
    <MinimumVisualStudioVersion>14.0</MinimumVisualStudioVersion>
    <AppContainerApplication>true</AppContainerApplication>
    <ApplicationType>Windows Store</ApplicationType>
    <WindowsTargetPlatformVersion>10.0.17763.0</WindowsTargetPlatformVersion>
    <WindowsTargetPlatformMinVersion>10.0.17763.0</WindowsTargetPlatformMinVersion>
    <ApplicationTypeRevision>10.0</ApplicationTypeRevision>
    <IncludeOutputsInPackage>false</IncludeOutputsInPackage>
    <TargetFramework>uap10.0</TargetFramework>
    <TargetOsAndVersion Condition="'$(TargetOsAndVersion)' == ''">Universal Windows</TargetOsAndVersion>
    <EnableDotNetNativeCompatibleProfile Condition="'$(EnableDotNetNativeCompatibleProfile)'==''">true</EnableDotNetNativeCompatibleProfile>
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
    <PlatformToolset>v141</PlatformToolset>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|ARM'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
    <PlatformToolset>v141</PlatformToolset>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <PlatformToolset>v141</PlatformToolset>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|ARM'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <PlatformToolset>v141</PlatformToolset>
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
    <Import Project="..\..\)~" + solutionName + LR"~(.Packageable.props" />
  </ImportGroup>
  <ImportGroup Label="Shared">
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'$(Configuration)|$(Platform)'=='Debug|ARM'">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'$(Configuration)|$(Platform)'=='Release|ARM'">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <PropertyGroup Label="UserMacros" />
  <PropertyGroup />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
    <GenerateManifest>false</GenerateManifest>
    <IgnoreImportLibrary>false</IgnoreImportLibrary>
    <IslandwoodDRT>true</IslandwoodDRT>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
    <GenerateManifest>false</GenerateManifest>
    <IgnoreImportLibrary>false</IgnoreImportLibrary>
    <IslandwoodDRT>true</IslandwoodDRT>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|ARM'">
    <GenerateManifest>false</GenerateManifest>
    <IgnoreImportLibrary>false</IgnoreImportLibrary>
    <IslandwoodDRT>true</IslandwoodDRT>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|ARM'">
    <GenerateManifest>false</GenerateManifest>
    <IgnoreImportLibrary>false</IgnoreImportLibrary>
    <IslandwoodDRT>true</IslandwoodDRT>
  </PropertyGroup>
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <CompileAsWinRT>false</CompileAsWinRT>
    </ClCompile>
    <Link>
      <SubSystem>Console</SubSystem>
      <IgnoreAllDefaultLibraries>false</IgnoreAllDefaultLibraries>
      <GenerateWindowsMetadata>false</GenerateWindowsMetadata>
      <ModuleDefinitionFile>$(MSBuildProjectDirectory)\..\..\)~" + g_srcDirectory + LR"~(%s_export.def</ModuleDefinitionFile>
    </Link>
    <ClangCompile>
      <AdditionalOptions> -fno-rtti -Wno-microsoft -Wno-extern-initializer  -Wno-ignored-attributes -DWINAPI_FAMILY=WINAPI_FAMILY_APP  -ffunction-sections  -fdata-sections -d2bigobj </AdditionalOptions>
      <IncludePaths>%%(IncludePaths);)~" + additionalIncludePaths + LR"~($(MSBuildProjectDirectory)\..\..\..\Universal;$(WINOBJC_SDK_ROOT)\include;$(WINOBJC_SDK_ROOT)\Frameworks\include;$(WINOBJC_SDK_ROOT)\include\xplat</IncludePaths>
      <UserIncludePaths>
      </UserIncludePaths>
      <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
      <PreprocessorDefinitions>DEBUG=1;%s="";)~" + _getPreprcessorDefineString(L"=1") + LR"~(;</PreprocessorDefinitions>
    </ClangCompile>
  </ItemDefinitionGroup>)~";
  vcxprojTemplate += LR"~(
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <CompileAsWinRT>false</CompileAsWinRT>
      <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
    </ClCompile>
    <Link>
      <SubSystem>Console</SubSystem>
      <IgnoreAllDefaultLibraries>false</IgnoreAllDefaultLibraries>
      <GenerateWindowsMetadata>false</GenerateWindowsMetadata>
      <ModuleDefinitionFile>$(MSBuildProjectDirectory)\..\..\)~" + g_srcDirectory + LR"~(%s_export.def</ModuleDefinitionFile>
    </Link>
    <ClangCompile>
      <AdditionalOptions> -fno-rtti -Wno-microsoft -Wno-extern-initializer  -Wno-ignored-attributes -DWINAPI_FAMILY=WINAPI_FAMILY_APP  -ffunction-sections  -fdata-sections -d2bigobj </AdditionalOptions>
      <IncludePaths>%%(IncludePaths);)~" + additionalIncludePaths + LR"~($(MSBuildProjectDirectory)\..\..\..\Universal;$(WINOBJC_SDK_ROOT)\include;$(WINOBJC_SDK_ROOT)\Frameworks\include;$(WINOBJC_SDK_ROOT)\include\xplat</IncludePaths>
      <OptimizationLevel>Full</OptimizationLevel>
      <WOCStdLib>true</WOCStdLib>
      <UserIncludePaths>
      </UserIncludePaths>
      <PreprocessorDefinitions>;%s="";)~" + _getPreprcessorDefineString(L"=1") + LR"~(;</PreprocessorDefinitions>
    </ClangCompile>
  </ItemDefinitionGroup>)~";
  vcxprojTemplate += LR"~(
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|arm'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <CompileAsWinRT>false</CompileAsWinRT>
    </ClCompile>
    <Link>
      <SubSystem>Console</SubSystem>
      <IgnoreAllDefaultLibraries>false</IgnoreAllDefaultLibraries>
      <GenerateWindowsMetadata>false</GenerateWindowsMetadata>
      <ModuleDefinitionFile>$(MSBuildProjectDirectory)\..\..\)~" + g_srcDirectory + LR"~(%s_export.def</ModuleDefinitionFile>
    </Link>
    <ClangCompile>
      <AdditionalOptions> -fno-rtti -Wno-microsoft -Wno-extern-initializer  -Wno-ignored-attributes -DWINAPI_FAMILY=WINAPI_FAMILY_APP  -ffunction-sections  -fdata-sections -d2bigobj </AdditionalOptions>
      <IncludePaths>%%(IncludePaths);)~" + additionalIncludePaths + LR"~($(MSBuildProjectDirectory)\..\..\..\Universal;$(WINOBJC_SDK_ROOT)\include;$(WINOBJC_SDK_ROOT)\Frameworks\include;$(WINOBJC_SDK_ROOT)\include\xplat</IncludePaths>
      <UserIncludePaths>
      </UserIncludePaths>
      <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
      <PreprocessorDefinitions>DEBUG=1;%s="";)~" + _getPreprcessorDefineString(L"=1") + LR"~(;</PreprocessorDefinitions>
    </ClangCompile>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|arm'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <CompileAsWinRT>false</CompileAsWinRT>
    </ClCompile>
    <Link>
      <SubSystem>Console</SubSystem>
      <IgnoreAllDefaultLibraries>false</IgnoreAllDefaultLibraries>
      <GenerateWindowsMetadata>false</GenerateWindowsMetadata>
      <ModuleDefinitionFile>$(MSBuildProjectDirectory)\..\..\)~" + g_srcDirectory + LR"~(%s_export.def</ModuleDefinitionFile>
    </Link>
    <ClangCompile>
      <AdditionalOptions> -fno-rtti -Wno-microsoft -Wno-extern-initializer  -Wno-ignored-attributes -DWINAPI_FAMILY=WINAPI_FAMILY_APP  -ffunction-sections  -fdata-sections -d2bigobj </AdditionalOptions>
      <IncludePaths>%%(IncludePaths);)~" + additionalIncludePaths + LR"~($(MSBuildProjectDirectory)\..\..\..\Universal;$(WINOBJC_SDK_ROOT)\include;$(WINOBJC_SDK_ROOT)\Frameworks\include;$(WINOBJC_SDK_ROOT)\include\xplat</IncludePaths>
      <OptimizationLevel>Full</OptimizationLevel>
      <WOCStdLib>true</WOCStdLib>
      <UserIncludePaths>
      </UserIncludePaths>
      <PreprocessorDefinitions>;%s="";)~" + _getPreprcessorDefineString(L"=1") + LR"~(;</PreprocessorDefinitions>
    </ClangCompile>
  </ItemDefinitionGroup>
%s
  )~" + packageReferences + LR"~(
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />
  <ImportGroup Label="ExtensionTargets">
    <Import Project="$(MSBuildProjectDirectory)\..\..\)~" + solutionName + LR"~(.Packageable.targets" />
    <Import Project="$(MSBuildProjectDirectory)\..\..\..\Common\WinObjC.Frameworks.UWP.Common.targets" Condition="Exists('$(SolutionDir)\..\..\..\Common\WinObjC.Frameworks.UWP.Common.targets')" />
    <Import Project="$(WINOBJC_SDK_ROOT)\common\winobjc.packagereference.override.targets" Condition="Exists('$(WINOBJC_SDK_ROOT)\common\winobjc.packagereference.override.targets')"/>
  </ImportGroup>
</Project>)~";
    // clang-format on
    _wmkdir(projectDirectoryPath.c_str());

    FILE* vcxproj = nullptr;
    if (_wfopen_s(&vcxproj, (projectDirectoryPath + L"\\" + module.first + L".vcxproj").c_str(), L"w")) {
        wprintf(L"Failed to open vcxproj file: %s\\%s.vcxproj\n", projectDirectoryPath.c_str(), module.first.c_str());
        exit(1);
    }

    wstring moduleDefine = moduleDefineFromName(module.first);
    wstring moduleName = module.first;

    fwprintf(vcxproj,
             vcxprojTemplate.c_str(),
             generateProjectReferences(module.second.second, types, moduleMap, namespaceMap).c_str(),
             module.second.first.c_str(), // project guid
             moduleName.c_str(), // Proj Name
             moduleName.c_str(), // Root Namespace
             moduleName.c_str(), // 4x .def
             moduleDefine.c_str(), // 4x moduleDefine
             moduleName.c_str(), // 4x .def
             moduleDefine.c_str(), // 4x moduleDefine
             moduleName.c_str(), // 4x .def
             moduleDefine.c_str(), // 4x moduleDefine
             moduleName.c_str(), // 4x .def
             moduleDefine.c_str(), // 4x moduleDefine
             generateClangCompileStatements(module.second.second).c_str()); // ClangCompile

    fclose(vcxproj);
}

void generatePropsFileForPackageable(const wstring& outputDirectory, const wstring& solutionFileName) {
    // clang-format off
    wstring content = LR"~(<?xml version="1.0" encoding="utf-8"?>
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetFramework>uap10.0</TargetFramework>
    <IncludeOutputsInPackage>false</IncludeOutputsInPackage>
    <IncludeContentInPackage>false</IncludeContentInPackage>
    <IncludeDefaultPackageContents Condition="'$(IncludeDefaultPackageContents)' == ''">true</IncludeDefaultPackageContents>
    <IncludeStaticLibraryInPackage Condition="'$(IncludeStaticLibraryInPackage)' == ''">true</IncludeStaticLibraryInPackage>
  </PropertyGroup>

  <ItemDefinitionGroup>
    <_MainProjectOutput>
      <IsPackable>$(IsPackable)</IsPackable>
      <IsNuGetized>$(IsNuGetized)</IsNuGetized>
    </_MainProjectOutput>
  </ItemDefinitionGroup>
</Project>
    )~";
    // clang-format on

    FILE* propsFile = nullptr;
    if (_wfopen_s(&propsFile, (outputDirectory + L"\\" + solutionFileName + L".Packageable.props").c_str(), L"w")) {
        wprintf(L"Failed to open project.json file\n");
        exit(1);
    }

    fwprintf(propsFile, content.c_str());

    fclose(propsFile);
}

void generateTargetsFileForPackageable(const wstring& outputDirectory, const wstring& solutionFileName) {
    // clang-format off

    wstring content = LR"~(<?xml version="1.0" encoding="utf-8"?>
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Target Name="AddBuiltOutput" BeforeTargets="GetPackageContents"  DependsOnTargets="$(ComputeLinkInputsTargets);BuiltProjectOutputGroup" Condition="'$(ConfigurationType)' == 'DynamicLibrary' or '$(ConfigurationType)' == 'Application'">
    <ItemGroup>
      <!-- Public include folder for project  -->
      <_IncludeFiles Include="@(PackageHeader)"/>

      <_ImportLibraryFileNames Include="@(Link -> '%%(ImportLibrary)')">
      </_ImportLibraryFileNames>

      <_WinMDFileNames Include="@(Link -> '%%(WindowsMetadataFile)')">
      </_WinMDFileNames>

      <PackageFile Include="@(_IncludeFiles->Distinct())" Condition="Exists('%%(FullPath)')">
        <PackagePath>build\include\UWP\%%(Filename)%%(Extension)</PackagePath>
      </PackageFile>

      <PackageFile Include="@(BuiltProjectOutputGroupOutput -> '%%(FinalOutputPath)')">
        <PackagePath>build\lib\$(TargetOsAndVersion)\$(PlatformTarget)\%%(Filename)%%(Extension)</PackagePath>
      </PackageFile>

      <PackageFile Include="@(_ImportLibraryFileNames->Distinct())" Condition="Exists('%%(FullPath)')">
        <PackagePath>build\lib\$(TargetOsAndVersion)\$(PlatformTarget)\%%(Filename)%%(Extension)</PackagePath>
      </PackageFile>

      <PackageFile Include="@(_WinMDFileNames->Distinct())" Condition="Exists('%%(FullPath)')">
        <PackagePath>build\lib\$(TargetOsAndVersion)\$(PlatformTarget)\%%(Filename)%%(Extension)</PackagePath>
      </PackageFile>
    </ItemGroup>
  </Target>
</Project>
    )~";
    // clang-format on

    FILE* targetsFile = nullptr;
    if (_wfopen_s(&targetsFile, (outputDirectory + L"\\" + solutionFileName + L".Packageable.targets").c_str(), L"w")) {
        wprintf(L"Failed to open targets file\n");
        exit(1);
    }

    fwprintf(targetsFile, content.c_str());

    fclose(targetsFile);
}

void generateDefExports(const vector<shared_ptr<NameSpace>>& namespaces, const wstring& fileName, const wstring& moduleName) {
    auto getName = [](const auto& entry) { return entry->Name; };

    // Find our exported classes:
    vector<wstring> exportedClasses;
    auto accumulateExports = [&](const auto& exportsList) {
        for_each(begin(exportsList), end(exportsList), [&](const auto& cls) { exportedClasses.push_back(getName(cls)); });
    };

    for (const auto& ns : namespaces) {
        accumulateExports(ns->RuntimeClasses);
        accumulateExports(ns->Structs);

        for (const auto& iface : ns->Interfaces) {
            if (iface->Name.find(L'`') != wstring::npos) {
                continue;
            }

            // If this is an exclusive interface, it doesn't need any of the backing stuff since that's created for the runtime
            // class instead
            if (iface->IsExclusiveTo) {
                continue;
            }

            exportedClasses.push_back(getName(iface));
        }
    }

    FILE* defs = nullptr;
    auto result = _wfopen_s(&defs, fileName.c_str(), L"w");
    if (result) {
        wprintf(L"Failed to open exports def file\n");
        exit(1);
    }

    // Before we do anything, clear the defs file so we're starting from scratch:
    fwprintf(defs, L"LIBRARY %s\n", moduleName.c_str());
    fwprintf(defs, L"    EXPORTS\n");

    // Get additional exports for ObjCUWP which are not exposed by Windows10.winmd and are created by hand.
    wstring lowercaseModuleName(moduleName.size(), 0);
    std::transform(moduleName.begin(), moduleName.end(), lowercaseModuleName.begin(), ::towlower);
    if (lowercaseModuleName == L"objcuwp") {
        _getAdditionalExportedClassesForObjCUWP(exportedClasses);
    }

    for (const auto& e : exportedClasses) {
        // These are special, don't export them (TODO make this less bad):
        WinrtType tmp;
        if (winrtTypeInfoBasic(e, &tmp)) {
            continue;
        }

        auto mappedName = mapNamespacedType(e);
        fwprintf(defs, L"     $_OBJC_CLASS_%s     DATA\n", mappedName.c_str());
        fwprintf(defs, L"     $_OBJC_REF_CLASS_%s DATA\n", mappedName.c_str());
    }
    fclose(defs);
}

Visitor* GetGeneratorVisitor(map<wstring, shared_ptr<Symbol>>& symMap, const wstring& outDir, map<wstring, wstring>& namespaceMap) {
    return new GeneratorVisitor(symMap, outDir, namespaceMap);
}
