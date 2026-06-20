//
//  StudioWatchComplicationBundle.swift
//  StudioWatchComplication
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import WidgetKit
import SwiftUI

@main
struct StudioWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        StudioTimerWatchComplication()
        StudioChartWatchComplication()
        StudioQuickStartWatchComplication()
    }
}
