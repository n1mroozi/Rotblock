//
//  DeviceActivityReport.swift
//  DeviceActivityReport
//
//  Created by n1 on 4/9/26.
//

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct RBDeviceActivityReport: DeviceActivityReportExtension {
    @MainActor
    var body: some DeviceActivityReportScene {
        RotblockTodayScene { viewModel in
            RotblockTodayView(viewModel: viewModel)
        }
    }
}
