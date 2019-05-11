#!/bin/bash

version="0.1"

cat > ./Sources/XcodeSimulatorKit/Version.swift <<EOF
// 
// NOTE: This file is automatically generated by generate-version-swift.sh.
// Should not be under version control.
//

public extension XcodeSimulatorTool {
    static var version: String {
        return "${version}"
    }
}
