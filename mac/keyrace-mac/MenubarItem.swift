//
//  MenubarItem.swift
//  keyrace-mac
//
//  Created by Nat Friedman on 1/3/21.
//

import Foundation
import Cocoa
import SwiftUI
import Charts

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

class TypingChart: BarChartView {
    func NewData(_ typingCount: [Int], color: [Int] = [255, 255, 0]) {
        let yse1 = typingCount.enumerated().map { x, y in return BarChartDataEntry(x: Double(x), y: Double(y)) }

        let data = BarChartData()
        let ds1 = BarChartDataSet(entries: yse1, label: "Hello")
        ds1.colors = [NSUIColor.init(srgbRed: CGFloat(color[0])/255.0, green: CGFloat(color[1])/255.0, blue: CGFloat(color[2])/255.0, alpha: 1.0)]
        data.addDataSet(ds1)
        data.barWidth = Double(0.5)

        data.setDrawValues(true)
        let valueFormatter = ChartValueFormatter()
        data.setValueFormatter(valueFormatter)

        self.data = data
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let xArray = Array(1..<24)
        let ys1 = xArray.map { x in return abs(sin(Double(x) / 2.0 / 3.141 * 1.5)) }
        
        let yse1 = ys1.enumerated().map { x, y in return BarChartDataEntry(x: Double(x), y: y) }

        let data = BarChartData()
        let ds1 = BarChartDataSet(entries: yse1, label: "Hello")
        ds1.colors = [NSUIColor.red]
        data.addDataSet(ds1)
        data.barWidth = Double(0.5)
        
        self.data = data
        
        self.legend.enabled = false
        self.leftAxis.drawGridLinesEnabled = false
        self.leftAxis.drawAxisLineEnabled = false
        self.leftAxis.drawLabelsEnabled = false
        self.rightAxis.drawGridLinesEnabled = false
        self.rightAxis.drawAxisLineEnabled = false
        self.rightAxis.drawLabelsEnabled = false
        self.xAxis.drawGridLinesEnabled = false
        self.xAxis.drawAxisLineEnabled = false
        self.xAxis.drawLabelsEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
