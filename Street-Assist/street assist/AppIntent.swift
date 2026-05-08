//
//  AppIntent.swift
//  street assist
//
//  Created by COBSCCOMP242P-050 on 2026-05-05.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Street-Assist Widget" }
    static var description: IntentDescription { "Shows streak progress and total points." }
}
