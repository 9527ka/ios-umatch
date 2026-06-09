//
//  widgetsBundle.swift
//  widgets
//
//  Created by lang on 2026/6/1.
//

import WidgetKit
import SwiftUI

@main
struct widgetsBundle: WidgetBundle {
    var body: some Widget {
        widgets()
        if #available(iOS 16.1, *) {
            UMMatchLiveActivity()
        }
    }
}
