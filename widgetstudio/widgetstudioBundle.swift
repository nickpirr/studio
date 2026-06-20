//
//  widgetstudioBundle.swift
//  widgetstudio
//
//  Created by Niccoló Pirronello on 20/05/26.
//

import WidgetKit
import SwiftUI

@main
struct widgetstudioBundle: WidgetBundle {
    var body: some Widget {
        widgetstudio()
        widgetstudioControl()
        widgetstudioLiveActivity()
        StudioWeeklyWidget()
        StudioQuickStartWidget()
        StudioStatusWidget()
    }
}
