import Foundation
import FMake

OutputLevel.default = .error

enum Config {
  static let libssh2Origin = "https://github.com/libssh2/libssh2.git"
  static let libssh2Tag = "libssh2-1.11.0"
  static let libssh2Version = "1.11.0"
  
  static let opensslLibsURL       = "https://github.com/holzschu/openssl-apple/releases/download/v1.1.1w/openssl-libs.zip"
  static let opensslFrameworksURL = "https://github.com/holzschu/openssl-apple/releases/download/v1.1.1w/openssl-dynamic.frameworks.zip"
  
  static let frameworkName = "libssh2"
  
  static let platforms: [Platform] = Platform.allCases
}

extension Platform {
  var deploymentTarget: String {
    switch self {
    case .AppleTVOS, .AppleTVSimulator,
         .iPhoneOS, .iPhoneSimulator: return "14.0"
    case .MacOSX, .Catalyst: return "11.0"
    case .WatchOS, .WatchSimulator: return "7.0"
    }
  }
}


try? sh("rm -rf libssh2")
try sh("git clone --depth 1 \(Config.libssh2Origin) --branch \(Config.libssh2Tag)")

try download(url: Config.opensslLibsURL)
try? sh("rm -rf openssl")
try? sh("mkdir -p openssl")
try sh("unzip openssl-libs.zip -d openssl")

try download(url: Config.opensslFrameworksURL)
try? sh("rm -rf openssl-frameworks")
try? sh("mkdir -p openssl-frameworks")
try sh("unzip openssl-dynamic.frameworks.zip -d openssl-frameworks")

let fm = FileManager.default
let cwd = fm.currentDirectoryPath
let opensslLibsRoot = "\(cwd)/openssl/libs/"
let toolchain = "\(cwd)/apple.cmake"

try write(content: appleCMake(), atPath: toolchain)

var dynamicFrameworkPaths: [String] = []
var staticFrameworkPaths: [String] = []

for p in Config.platforms {
  let ldflags = "-fembed-bitcode"
  let cflags = "-fembed-bitcode"
  let cppflags = "-fembed-bitcode"

  var env = try [
    "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "",
    "APPLE_PLATFORM": p.sdk,
    "APPLE_SDK_PATH": p.sdkPath(),
    "SECOND_FIND_ROOT_PATH": "\(opensslLibsRoot + p.name)/openssl",
    "LDFLAGS": ldflags,
    "CFLAGS": cflags,
    "CPPFLAGS": cppflags
  ]

  let frameworkDynamicPath = "frameworks/dynamic/\(p.name)/\(Config.frameworkName).framework"
  let frameworkStaticPath = "frameworks/static/\(p.name)/\(Config.frameworkName).framework"
  dynamicFrameworkPaths.append(frameworkDynamicPath)
  staticFrameworkPaths.append(frameworkStaticPath)
  
  for arch in p.archs {
    
    print(env)
    print(arch)
    print("Debugging")
    
    if p == .Catalyst {
      env["LDFLAGS"] = "\(ldflags) -target \(arch)-apple-ios14.0-macabi"
      env["CFLAGS"] = "\(cflags) -target \(arch)-apple-ios14.0-macabi"
    }
    
    let libPath = "lib/\(p.name)-\(arch).sdk"
    let binPath = "bin/\(p.name)-\(arch).sdk"
    
    try? sh("rm -rf \(binPath)")
    
    try? sh("rm -rf \(libPath)")
    try? mkdir(libPath)

    try print(
      "Command: cmake",
      "-Hlibssh2 -B\(binPath)",
      "-GXcode",
      "-DCMAKE_TOOLCHAIN_FILE=\(toolchain)",
      "-DCMAKE_C_COMPILER=\(p.ccPath())",
      "-DCMAKE_OSX_ARCHITECTURES=\(arch)",
      "-DCMAKE_OSX_DEPLOYMENT_TARGET=\(p.deploymentTarget)",
      "-DBUILD_SHARED_LIBS=OFF",
      "-DWITH_EXAMPLES=OFF",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO",
      "-DCMAKE_SYSTEM_PROCESSOR=\(arch)",
//      "-DCMAKE_C_FLAGS=\"-target x86_64-apple-ios13.0-macabi -mios-version-min=13.0 -isystem \(try p.sdkPath())/System/iOSSupport/usr/include -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.1.sdk/System/iOSSupport/System/Library/Frameworks\"",
//      "-DCMAKE_CXX_FLAGS=\"-target x86_64-apple-ios13.0-macabi -mios-version-min=13.0\"",
//      "-DCMAKE_LDFLAGS=\"-target x86_64-apple-ios13.0-macabi  -L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/maccatalyst  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.1.sdk/System/iOSSupport/usr/lib -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.1.sdk/System/iOSSupport/System/Library/Frameworks \"",
      "-DCMAKE_INSTALL_PREFIX=\(libPath)",
      "-DBUILD_EXAMPLES=NO",
      "-DBUILD_TESTING=NO",
      "-DENABLE_ZLIB_COMPRESSION=YES",
      "-DENABLE_CRYPT_NONE=YES",
      "-DENABLE_MAC_NONE=YES")

    try sh(
      "cmake",
      "-Hlibssh2 -B\(binPath)",
      "-GXcode",
      "-DCMAKE_TOOLCHAIN_FILE=\(toolchain)",
      "-DCMAKE_C_COMPILER=\(p.ccPath())",
      "-DCMAKE_OSX_ARCHITECTURES=\(arch)",
      "-DCMAKE_OSX_DEPLOYMENT_TARGET=\(p.deploymentTarget)",
      "-DBUILD_SHARED_LIBS=OFF",
      "-DWITH_EXAMPLES=OFF",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO",
      "-DCMAKE_SYSTEM_PROCESSOR=\(arch)",
//      "-DCMAKE_C_FLAGS=\"-target x86_64-apple-ios13.0-macabi -mios-version-min=13.0 -isystem \(try p.sdkPath())/System/iOSSupport/usr/include -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.1.sdk/System/iOSSupport/System/Library/Frameworks\"",
//      "-DCMAKE_CXX_FLAGS=\"-target x86_64-apple-ios13.0-macabi -mios-version-min=13.0\"",
//      "-DCMAKE_LDFLAGS=\"-target x86_64-apple-ios13.0-macabi  -L/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/maccatalyst  -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.1.sdk/System/iOSSupport/usr/lib -iframework /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.1.sdk/System/iOSSupport/System/Library/Frameworks \"",
      "-DCMAKE_INSTALL_PREFIX=\(libPath)",
      "-DBUILD_EXAMPLES=NO",
      "-DBUILD_TESTING=NO",
      "-DENABLE_ZLIB_COMPRESSION=YES",
      "-DENABLE_CRYPT_NONE=YES",
      "-DENABLE_MAC_NONE=YES"
      , env: env)
    
    try sh(
      "cmake",
      "--build \(binPath)",
      "--config Release",
      "--target install"
    )
    
    try? mkdir("\(binPath)/tmp")
    
    // 1. makeing dylib
    
    try? mkdir("\(binPath)/obj")
    try cd("\(binPath)/obj") {
      try sh("ar -x \(cwd)/\(libPath)/lib/libssh2.a")
    }
    
    // dynamic framework
    try sh(
      "ld",
      "\(binPath)/obj/*.o",
      "-bitcode_bundle",
      "-dylib",
      "-lSystem",
      "-lz",
      "-Fopenssl-frameworks/\(p.name)",
      "-framework Foundation",
      "-framework openssl",
      "-arch \(arch)",
      "-\(p.plistMinSDKVersionName) \(p.deploymentTarget)",
      "-syslibroot \(p.sdkPath())",
      "-compatibility_version 1.0.0",
      "-current_version 1.0.0",
      "-application_extension",
      "-o \(binPath)/\(Config.frameworkName)"
    )
    
    try sh(
      "install_name_tool",
      "-id",
      "@rpath/\(Config.frameworkName).framework/\(Config.frameworkName)",
      "\(binPath)/\(Config.frameworkName)"
    )
    
    try sh("rm -rf \(binPath)/obj")
    
    
    // 2. creating static lib
    try mkdir("\(binPath)/lib")
    try sh(
      "lipo -create \(libPath)/lib/libssh2.a -output \(binPath)/tmp/libssh2.a"
    )
  }
  
  guard
    let arch = p.archs.first
  else {
    continue
  }
  
  let libPath = "lib/\(p.name)-\(arch).sdk"
  
  let plist = try p.plist(
    name: Config.frameworkName,
    version: Config.libssh2Version,
    id: "org.libssh2",
    minSdkVersion: p.deploymentTarget
  )
  
  let moduleMap = p.module(name: Config.frameworkName, headers: .umbrellaDir("."))
  
  for path in [frameworkStaticPath, frameworkDynamicPath] {
    try? sh("rm -rf", path)
    try mkdir("\(path)/Headers")
    try sh("cp \(libPath)/include/*.h \(path)/Headers/")
    try write(content: plist, atPath: "\(path)/Info.plist")
    try mkdir("\(path)/Modules")
    try write(content: moduleMap, atPath: "\(path)/Modules/module.modulemap")
  }
  
  let aFiles = p.archs.map { arch -> String in
    "bin/\(p.name)-\(arch).sdk/tmp/*.a"
  }
  
  try sh("libtool -static -o \(frameworkStaticPath)/\(Config.frameworkName) \(aFiles.joined(separator: " "))")
  
  let dylibFiles = p.archs.map { arch -> String in
    "bin/\(p.name)-\(arch).sdk/\(Config.frameworkName)"
  }
  
  try sh("lipo -create \(dylibFiles.joined(separator: " ")) -output \(frameworkDynamicPath)/\(Config.frameworkName)")
  
  if p == .MacOSX || p == .Catalyst {
    for path in [frameworkStaticPath, frameworkDynamicPath] {
      try repackFrameworkToMacOS(at: path, name: Config.frameworkName)
    }
  }
}


try? sh("rm -rf xcframeworks")
try mkdir("xcframeworks/dynamic")
try mkdir("xcframeworks/static")

let xcframeworkName = "\(Config.frameworkName).xcframework"
let xcframeworkdDynamicZipName = "\(Config.frameworkName)-dynamic.xcframework.zip"
let xcframeworkdStaticZipName = "\(Config.frameworkName)-static.xcframework.zip"
try? sh("rm \(xcframeworkdDynamicZipName)")
try? sh("rm \(xcframeworkdStaticZipName)")

try sh(
  "xcodebuild -create-xcframework \(dynamicFrameworkPaths.map {"-framework \($0)"}.joined(separator: " ")) -output xcframeworks/dynamic/\(xcframeworkName)"
)

try cd("xcframeworks/dynamic/") {
  try sh("zip --symlinks -r ../../\(xcframeworkdDynamicZipName) \(xcframeworkName)")
}

try sh(
  "xcodebuild -create-xcframework \(staticFrameworkPaths.map {"-framework \($0)"}.joined(separator: " ")) -output xcframeworks/static/\(xcframeworkName)"
)


try cd("xcframeworks/static/") {
  try sh("zip --symlinks -r ../../\(xcframeworkdStaticZipName) \(xcframeworkName)")
}


let releaseMD =
  """
    | File                          | SHA256                                       |
    | ----------------------------- |:--------------------------------------------:|
    | \(xcframeworkdDynamicZipName) | \(try sha(path: xcframeworkdDynamicZipName)) |
    | \(xcframeworkdStaticZipName)  | \(try sha(path: xcframeworkdStaticZipName))  |
  """

try write(content: releaseMD, atPath: "release.md")
