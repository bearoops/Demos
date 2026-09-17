//
//  TestWidgetBundle.swift
//  TestWidget
//
//  Created by issuser on 2026/9/17.
//

import WidgetKit
import SwiftUI

@main
struct TestWidgetBundle: WidgetBundle {
    var body: some Widget {
        TestWidget()
        TestWidgetControl()
        TestWidgetLiveActivity()
    }
}
