//
//  InteractiveStatisticsChart.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import Charts

@available(iOS 16.0, *)
struct InteractiveStatisticsChart: View {
    let data: [StatisticsDataPoint]
    @State private var selectedDataPoint: StatisticsDataPoint?
    @State private var chartType: ChartType = .line
    
    enum ChartType: String, CaseIterable {
        case line = "Line"
        case bar = "Bar"
        case area = "Area"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart Type Picker
            Picker("Chart Type", selection: $chartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Chart
            Chart(data) { dataPoint in
                switch chartType {
                case .line:
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                case .bar:
                    BarMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue.gradient)
                    
                case .area:
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue.gradient.opacity(0.3))
                    
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue)
                }
                
                // Selection indicator
                if let selectedDataPoint = selectedDataPoint,
                   selectedDataPoint.id == dataPoint.id {
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(100)
                }
            }
            .frame(height: 200)
            .chartAngleSelection(value: .constant(nil))
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            selectDataPoint(at: location, geometry: geometry, chartProxy: chartProxy)
                        }
                }
            }
            
            // Selected data point info
            if let selectedDataPoint = selectedDataPoint {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Data Point")
                        .font(.headline)
                    Text("Date: \(selectedDataPoint.date, formatter: dateFormatter)")
                    Text("Value: \(selectedDataPoint.value, specifier: "%.2f")")
                    Text("Category: \(selectedDataPoint.category)")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private func selectDataPoint(at location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy) {
        // Convert tap location to chart coordinates
        let plotAreaFrame = geometry.frame(in: .local)
        let xPosition = location.x - plotAreaFrame.minX
        
        // Find the closest data point
        if let date = chartProxy.value(atX: xPosition, as: Date.self) {
            selectedDataPoint = data.min { dataPoint1, dataPoint2 in
                abs(dataPoint1.date.timeIntervalSince(date)) < abs(dataPoint2.date.timeIntervalSince(date))
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

struct StatisticsDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let category: String
}
