//
//  MenubarItem.swift
//  keyrace-mac
//
//  Created by Nat Friedman on 1/3/21.
//

import Charts
import Cocoa
import Foundation
import SwiftUI

class ChartValueFormatter: NSObject, IValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if value == 0.0 {
            return ""
        }

        return String(Int(value))
    }
}

public class MinAxisValueFormatter: NSObject, IAxisValueFormatter {
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date()
        let calendar = Calendar.current
        let min = calendar.component(.minute, from: date)
        
        var m = min - 20 + Int(value)
        if m < 0 {
            m += 60
        }
        
        return String(format: ":%02d", m)
    }
}

public class HourAxisValueFormatter: NSObject, IAxisValueFormatter {
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if (value == 12.0) {
            return "noon"
        }
        if (value == 0.0) {
            return "12am"
        }

        var str = "\(Int(value)%12)"
        
        if (value < 12.0) {
            str += "am"
        } else {
            str += "pm"
        }
        
        return str
    }
}

public class KeyAxisValueFormatter: NSObject, IAxisValueFormatter {
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return "\(Character(UnicodeScalar(Int(97 + value))!))" // 97 is 'a'
    }
}

public class SymbolAxisValueFormatter: NSObject, IAxisValueFormatter {
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return "\(Character(UnicodeScalar(Int(33 + value))!))" // 33 is '!'
    }
}

struct TypingChart: NSViewRepresentable {
    // TypingChart accepts a typingCount and a color.
    var typingCount: [Int]
    var color: [Int] = [255, 255, 0]
    var granularity: Double
    var valueFormatter: IAxisValueFormatter
    var labelCount: Int
    
    
    func makeNSView(context: Context) -> BarChartView {
        // Create the typing chart.
        let chart = BarChartView(frame: CGRect(x: 0, y: 0, width: 350, height: 100))
        
        chart.legend.enabled = false
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.drawAxisLineEnabled = false
        chart.leftAxis.drawLabelsEnabled = false
        chart.rightAxis.drawGridLinesEnabled = false
        chart.rightAxis.drawAxisLineEnabled = false
        chart.rightAxis.drawLabelsEnabled = false
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.drawAxisLineEnabled = false
        chart.xAxis.drawLabelsEnabled = false
        
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 8.0)
        chart.xAxis.drawLabelsEnabled = true
        chart.xAxis.granularity = granularity
        if labelCount > 0 {
            chart.xAxis.labelCount = labelCount
        }
        chart.xAxis.valueFormatter = valueFormatter
        
        chart.data = addData()
        
        return chart
    }
    
    func updateNSView(_ nsView: BarChartView, context: Context) {
        // When the typing count changes, change the view.
        nsView.data = addData()
    }
    
    typealias NSViewType = BarChartView
    
    func addData() -> BarChartData {
        let yse1 = typingCount.enumerated().map { x, y in return BarChartDataEntry(x: Double(x), y: Double(y)) }

        let data = BarChartData()
        let ds1 = BarChartDataSet(entries: yse1, label: "Hello")
        ds1.colors = [NSUIColor.init(srgbRed: CGFloat(color[0])/255.0, green: CGFloat(color[1])/255.0, blue: CGFloat(color[2])/255.0, alpha: 1.0)]
        data.addDataSet(ds1)
        data.barWidth = Double(0.5)

        data.setDrawValues(true)
        let valueFormatter = ChartValueFormatter()
        data.setValueFormatter(valueFormatter)

        return data
    }
}
