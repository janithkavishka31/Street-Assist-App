//
//  Street_Assist_PulseBundle.swift
//  Street-Assist Pulse
//
//  Created by COBSCCOMP242P-050 on 2026-05-07.
//

import WidgetKit
import SwiftUI

@main
struct Street_Assist_PulseBundle: WidgetBundle {
    var body: some Widget {
        Street_Assist_Pulse()
        Street_Assist_PulseControl()
        Street_Assist_PulseLiveActivity()
    }
}
