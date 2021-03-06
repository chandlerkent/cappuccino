require("narwhal").ensureEngine("rhino");

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "objj-analysis-tools.j"
@import "cib-analysis-tools.j"

var FILE = require("file");
var OS = require("os");

var stream = require("term").stream;
var parser = new (require("args").Parser)();

parser.usage("INPUT_PROJECT OUTPUT_PROJECT");
parser.help("Analyze and strip unused files from a Cappuccino project's .sj bundles.");

parser.option("-m", "--main", "main")
    .def("main.j")
    .set()
    .help("The relative path (from INPUT_PROJECT) to the main file (default: 'main.j')");

parser.option("-F", "--framework", "frameworks")
    .def(["Frameworks"])
    .push()
    .help("Add a frameworks directory, relative to INPUT_PROJECT (default: ['Frameworks'])");

parser.option("-E", "--environment", "environments")
    .def(['Browser'])
    .push()
    .help("Add a platform name (default: ['Browser'])");

parser.option("-f", "--force", "force")
   .def(false)
   .set(true)
   .help("Force overwriting OUTPUT_PROJECT if it exists");

parser.option("-p", "--pngcrush", "png")
    .def(false)
    .set(true)
    .help("Run pngcrush on all PNGs (pngcrush must be installed!)");

parser.option("-v", "--verbose", "verbose")
    .def(false)
    .set(true)
    .help("Verbose logging");

parser.helpful();

function main(args)
{
    var options = parser.parse(args);

    if (options.args.length < 2) {
        parser.printUsage(options);
        return;
    }

    CPLogRegister(CPLogPrint);

    // HACK: ensure trailing slashes for "relative" to work correctly
    var rootPath = FILE.path(options.args[0]).join("").absolute();
    var outputPath = FILE.path(options.args[1]).join("").absolute();

    if (outputPath.exists()) {
        if (options.force) {
            // FIXME: why doesn't this work?!
            //outputPath.rmtree();
            OS.system(["rm", "-rf", outputPath]);
        } else {
            CPLog.error("OUTPUT_PROJECT " + outputPath + " exists. Use -f to overwrite.");
            OS.exit(1);
        }
    }

    press(rootPath, outputPath, options);
}

function press(rootPath, outputPath, options) {
    stream.print("\0yellow("+Array(81).join("=")+"\0)");
    stream.print("Application root:    \0green(" + rootPath + "\0)");
    stream.print("Output directory:    \0green(" + outputPath + "\0)");

    var outputFiles = {};

    // analyze and gather files for each environment:
    options.environments.forEach(function(environment) {
        pressEnvironment(rootPath, outputFiles, environment, options);
    });

    // phase 4: copy everything and write out the new files
    stream.print("\0red(PHASE 4:\0) copy to output \0green(" + rootPath + "\0) => \0green(" + outputPath + "\0)");

    FILE.copyTree(rootPath, outputPath);

    for (var path in outputFiles) {
        var file = outputPath.join(rootPath.relative(path));

        var parent = file.dirname();
        if (!parent.exists()) {
            CPLog.warn(parent + " doesn't exist, creating directories.");
            parent.mkdirs();
        }

        if (typeof outputFiles[path] !== "string")
            outputFiles[path] = outputFiles[path].join("");

        stream.print((file.exists() ? "\0red(Overwriting:\0) " : "\0green(Writing:\0)     ") + file);

        FILE.write(file, outputFiles[path], { charset : "UTF-8" });
    }

    // strip known unnecessary files
    // outputPath.glob("**/Frameworks/Debug").forEach(function(debugFramework) {
    //     outputPath.join(debugFramework).rmtree();
    // });
    // outputPath.join("index-debug.html").remove();

    if (options.png) {
        pngcrushDirectory(outputPath);
    }
}

function pressEnvironment(rootPath, outputFiles, environment, options) {

    var mainPath = String(rootPath.join(options.main));
    var frameworks = options.frameworks.map(function(framework) { return rootPath.join(framework); });

    stream.print("\0yellow("+Array(81).join("=")+"\0)");
    stream.print("Main file:           \0green(" + mainPath + "\0)");
    stream.print("Frameworks:          \0green(" + frameworks + "\0)");
    stream.print("Environment:         \0green(" + environment + "\0)");

    var analyzer = new ObjectiveJRuntimeAnalyzer(rootPath);

    var _OBJJ = analyzer.require("objective-j");

    // include paths:
    analyzer.setIncludePaths(frameworks);
    // environments:
    analyzer.setEnvironments([environment, "ObjJ"]);

    // build list of cibs to inspect for dependent classes
    // FIXME: what's the best way to determine which cibs to look in?
    var cibs = FILE.glob(rootPath.join("**", "*.cib")).filter(function(path) { return !(/Frameworks/).test(path); });

    // phase 1: get global defines
    stream.print("\0red(PHASE 1:\0) Loading application...");

    analyzer.initializeGlobalRecorder();

    analyzer.load(mainPath);

    analyzer.finishLoading();

    // coalesce the results
    var dependencies = analyzer.mapGlobalsToFiles();

    // log identifer => files defining
    stream.print("Global defines:");
    Object.keys(dependencies).sort().forEach(function(identifier) {
        stream.print("\0blue(" + identifier + "\0) => \0cyan(" + dependencies[identifier].map(rootPath.relative.bind(rootPath)) + "\0)");
    });

    // phase 2: walk the dependency tree (both imports and references) to determine exactly which files need to be included
    stream.print("\0red(PHASE 2:\0) Traverse dependency graph...");

    var requiredFiles = {};
    requiredFiles[mainPath] = true;

    var context = {
        ignoreFrameworkImports : true, // ignores "XXX/XXX.j" imports
        importCallback: function(importing, imported) { requiredFiles[imported] = true; },
        referenceCallback: function(referencing, referenced) { requiredFiles[referenced] = true; },
        progressCallback: function(relPath) { stream.print("Processing \0cyan("+relPath+"\0)"); },
        ignoreFrameworkImportsCallback : function(relPath) { stream.print("\0yellow(Ignoring imports in "+relPath+"\0)"); }
    }

    mainExecutable = analyzer.executableForImport(mainPath);

    // check the code
    analyzer.traverseDependencies(mainExecutable, context);

    // check the cibs
    var globalsToFiles = analyzer.mapGlobalsToFiles();
    cibs.forEach(function(cibPath) {
        var cibClasses = findCibClassDependencies(cibPath);
        stream.print("Cib: \0green("+rootPath.relative(cibPath)+"\0) => \0cyan("+cibClasses+"\0)");

        var referencedFiles = {};
        markFilesReferencedByTokens(cibClasses, globalsToFiles, referencedFiles);
        analyzer.checkReferenced(context, null, referencedFiles);
    });

    var included = 0, total = 0;
    var includedBytes = 0, totalBytes = 0;
    var allFiles = analyzer.fileExecutables();
    for (var path in allFiles) {
        // mark all ".keytheme"s as required
        if (/\.keyedtheme$/.test(path))
            requiredFiles[path] = true;

        if (requiredFiles[path]) {
            stream.print("Included: \0green(" + rootPath.relative(path) + "\0)");
            included++;
            includedBytes += allFiles[path].code().length
        }
        else {
            stream.print("Excluded: \0red(" + rootPath.relative(path) + "\0)");
        }
        total++;
        totalBytes += allFiles[path].code().length
    }
    stream.print(sprintf(
        "Saved \0green(%f%%\0) (\0blue(%s\0)); Total required files: \0magenta(%d\0) (\0blue(%s\0)) of \0magenta(%d\0) (\0blue(%s\0));",
        Math.round(((includedBytes - totalBytes) / totalBytes) * -100),
        bytesToString(totalBytes - includedBytes),
        included, bytesToString(includedBytes),
        total, bytesToString(totalBytes)
    ));

    // phase 3b: rebuild .sj files with correct imports, copy .j files
    stream.print("\0red(PHASE 3b:\0) Rebuild .sj files");

    for (var path in requiredFiles)
    {
        var executable = analyzer.executableForImport(path),
            bundle = _OBJJ.CFBundle.bundleContainingPath(executable.path()),
            relativePath = FILE.relative(FILE.join(bundle.path(), ""), executable.path());

        if (executable.path() !== path)
            CPLog.warn("Sanity check failed (file path): " + executable.path() + " vs. " + path);

        if (bundle && bundle.infoDictionary())
        {
            var executablePath = bundle.executablePath();
            if (executablePath)
            {
                if (context.ignoredImports[path])
                {
                    stream.print("Stripping extra imports from \0blue(" + path + "\0)");

                    var code = executable.code();
                    var dependencies = executable.fileDependencies();
                    for (var i = 0; i < dependencies.length; i++) {
                        var dependency = dependencies[i];
                        var dependencyExecutable = new _OBJJ.FileExecutableSearch(
                            dependency.isLocal() ? FILE.join(FILE.dirname(path), dependency.path()) : dependency.path(),
                            dependency.isLocal()
                        ).result();
                        var dependencyPath = dependencyExecutable.path();
                        if (!requiredFiles[dependencyPath]) {
                            stream.print(" -> \0red(" + dependencyPath + "\0)");
                            // build up a regex to match objj_executeFile with optional whitespace
                            var regex = new RegExp([
                                RegExp.escape("objj_executeFile"),
                                RegExp.escape("("),
                                "[\"']"+RegExp.escape(dependency.path())+"[\"']",
                                RegExp.escape(","),
                                RegExp.escape(dependency.isLocal() ? "true" : "false"),
                                RegExp.escape(")")
                            ].join("\\s*"), "g");
                            // replace instances of "objj_executeFile()" with "(undefined)"
                            code = code.replace(regex, "/* $& */ (undefined)");
                            // remove from dependencies list (decrement i since we're removing an item)
                            dependencies.splice(i--, 1);
                        }
                    }
                    if (code !== executable.code())
                        executable.setCode(code);
                }

                if (!outputFiles[executablePath])
                {
                    outputFiles[executablePath] = [];
                    outputFiles[executablePath].push("@STATIC;1.0;");
                }

                var fileContents = executable.toMarkedString();

                outputFiles[executablePath].push("p;" + relativePath.length + ";" + relativePath);
                outputFiles[executablePath].push("t;" +  fileContents.length + ";" +  fileContents);

                stream.print("Adding \0green(" + rootPath.relative(path) + "\0) to \0cyan(" + rootPath.relative(executablePath) + "\0)");
            }
            else
            {
                stream.print("Passing .j through: \0green(" + rootPath.relative(path) + "\0)");
            }
        }
        else
            CPLog.warn("No bundle (or info dictionary for) " + rootPath.relative(path));
    }
}

function pngcrushDirectory(directory) {
    var directoryPath = FILE.path(directory);
    var pngs = directoryPath.glob("**/*.png");

    system.stderr.print("Running pngcrush on " + pngs.length + " pngs:");
    pngs.forEach(function(dst) {
        var dstPath = directoryPath.join(dst);
        var tmpPath = FILE.path(dstPath+".tmp");

        var p = OS.popen(["pngcrush", "-rem", "alla", "-reduce", /*"-brute",*/ dstPath, tmpPath]);
        if (p.wait()) {
            CPLog.warn("pngcrush failed. Ensure it's installed and on your PATH.");
        }
        else {
            FILE.move(tmpPath, dstPath);
            system.stderr.write(".").flush();
        }
    });
    system.stderr.print("");
}

function bytesToString(bytes) {
    var n = 0;
    while (bytes > 1024) {
        bytes /= 1024;
        n++;
    }
    return Math.round(bytes*100)/100 + " " + ["", "K", "M"][n] + "B";
}
