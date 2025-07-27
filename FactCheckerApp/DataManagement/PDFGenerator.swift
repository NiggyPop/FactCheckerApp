//
//  PDFGenerator.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import PDFKit
import UIKit

class PDFGenerator {
    private let pageSize = CGSize(width: 612, height: 792) // US Letter
    private let margin: CGFloat = 50
    
    func generatePDF(results: [FactCheckResult], outputURL: URL) throws {
        let pdfMetaData = [
            kCGPDFContextCreator: "FactCheck Pro",
            kCGPDFContextAuthor: "FactCheck Pro App",
            kCGPDFContextTitle: "Fact Check Results Export"
        ]
        
        guard let pdfContext = CGContext(url: outputURL as CFURL, mediaBox: nil, pdfMetaData as CFDictionary) else {
            throw ExportError.fileCreationFailed
        }
        
        var currentY: CGFloat = pageSize.height - margin
        var pageNumber = 1
        
        // Start first page
        pdfContext.beginPDFPage(nil)
        
        // Add title
        currentY = addTitle(to: pdfContext, y: currentY)
        currentY -= 30
        
        // Add results
        for (index, result) in results.enumerated() {
            let resultHeight = estimateResultHeight(result)
            
            // Check if we need a new page
            if currentY - resultHeight < margin {
                // End current page and start new one
                pdfContext.endPDFPage()
                pdfContext.beginPDFPage(nil)
                pageNumber += 1
                currentY = pageSize.height - margin
                
                // Add page number
                addPageNumber(to: pdfContext, pageNumber: pageNumber)
                currentY -= 30
            }
            
            currentY = addFactCheckResult(to: pdfContext, result: result, y: currentY)
            currentY -= 20 // Space between results
        }
        
        // Add page number to first/last page
        addPageNumber(to: pdfContext, pageNumber: pageNumber)
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }
    
    private func addTitle(to context: CGContext, y: CGFloat) -> CGFloat {
        let title = "FactCheck Pro - Export Report"
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (pageSize.width - titleSize.width) / 2
        
        title.draw(at: CGPoint(x: titleX, y: y - titleSize.height), withAttributes: titleAttributes)
        
        // Add export date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let dateText = "Generated on \(dateFormatter.string(from: Date()))"
        let dateFont = UIFont.systemFont(ofSize: 12)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.gray
        ]
        
        let dateSize = dateText.size(withAttributes: dateAttributes)
        let dateX = (pageSize.width - dateSize.width) / 2
        
        dateText.draw(at: CGPoint(x: dateX, y: y - titleSize.height - dateSize.height - 10), withAttributes: dateAttributes)
        
        return y - titleSize.height - dateSize.height - 20
    }
    
    private func addFactCheckResult(to context: CGContext, result: FactCheckResult, y: CGFloat) -> CGFloat {
        var currentY = y
        let contentWidth = pageSize.width - (margin * 2)
        
        // Add separator line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: currentY))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: currentY))
        context.strokePath()
        currentY -= 15
        
        // Date and veracity header
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let headerText = "\(dateFormatter.string(from: result.timestamp)) - \(result.veracity.rawValue.uppercased())"
        let headerFont = UIFont.boldSystemFont(ofSize: 14)
        let headerColor = colorForVeracity(result.veracity)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: headerColor
        ]
        
        let headerSize = headerText.size(withAttributes: headerAttributes)
        headerText.draw(at: CGPoint(x: margin, y: currentY - headerSize.height), withAttributes: headerAttributes)
        
        // Confidence
        let confidenceText = "Confidence: \(Int(result.confidence * 100))%"
        let confidenceSize = confidenceText.size(withAttributes: headerAttributes)
        confidenceText.draw(at: CGPoint(x: pageSize.width - margin - confidenceSize.width, y: currentY - confidenceSize.height), withAttributes: headerAttributes)
        
        currentY -= headerSize.height + 10
        
        // Statement
        let statementFont = UIFont.systemFont(ofSize: 12)
        let statementAttributes: [NSAttributedString.Key: Any] = [
            .font: statementFont,
            .foregroundColor: UIColor.black
        ]
        
        let statementRect = CGRect(x: margin, y: currentY - 100, width: contentWidth, height: 100)
        let statementSize = result.statement.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: statementAttributes,
            context: nil
        )
        
        result.statement.draw(in: CGRect(x: margin, y: currentY - statementSize.height, width: contentWidth, height: statementSize.height), withAttributes: statementAttributes)
        currentY -= statementSize.height + 15
        
        // Sources
        if !result.sources.isEmpty {
            let sourcesHeaderText = "Sources (\(result.sources.count)):"
            let sourcesHeaderFont = UIFont.boldSystemFont(ofSize: 11)
            let sourcesHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: sourcesHeaderFont,
                .foregroundColor: UIColor.darkGray
            ]
            
            let sourcesHeaderSize = sourcesHeaderText.size(withAttributes: sourcesHeaderAttributes)
            sourcesHeaderText.draw(at: CGPoint(x: margin, y: currentY - sourcesHeaderSize.height), withAttributes: sourcesHeaderAttributes)
            currentY -= sourcesHeaderSize.height + 5
            
            for (index, source) in result.sources.prefix(3).enumerated() {
                let sourceText = "\(index + 1). \(source.title) - \(Int(source.credibilityScore * 100))%"
                let sourceFont = UIFont.systemFont(ofSize: 10)
                let sourceAttributes: [NSAttributedString.Key: Any] = [
                    .font: sourceFont,
                    .foregroundColor: UIColor.darkGray
                ]
                
                let sourceSize = sourceText.size(withAttributes: sourceAttributes)
                sourceText.draw(at: CGPoint(x: margin + 10, y: currentY - sourceSize.height), withAttributes: sourceAttributes)
                currentY -= sourceSize.height + 3
            }
        }
        
        return currentY - 10
    }
    
    private func addPageNumber(to context: CGContext, pageNumber: Int) {
        let pageText = "Page \(pageNumber)"
        let pageFont = UIFont.systemFont(ofSize: 10)
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: pageFont,
            .foregroundColor: UIColor.gray
        ]
        
        let pageSize = pageText.size(withAttributes: pageAttributes)
        let pageX = (self.pageSize.width - pageSize.width) / 2
        
        pageText.draw(at: CGPoint(x: pageX, y: margin / 2), withAttributes: pageAttributes)
    }
    
    private func estimateResultHeight(_ result: FactCheckResult) -> CGFloat {
        let contentWidth = pageSize.width - (margin * 2)
        let statementFont = UIFont.systemFont(ofSize: 12)
        let statementAttributes: [NSAttributedString.Key: Any] = [.font: statementFont]
        
        let statementSize = result.statement.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: statementAttributes,
            context: nil
        )
        
        let baseHeight: CGFloat = 60 // Header + margins
        let sourcesHeight: CGFloat = result.sources.isEmpty ? 0 : CGFloat(min(result.sources.count, 3) * 15 + 20)
        
        return baseHeight + statementSize.height + sourcesHeight
    }
    
    private func colorForVeracity(_ veracity: FactVeracity) -> UIColor {
        switch veracity {
        case .true:
            return UIColor.systemGreen
        case .false:
            return UIColor.systemRed
        case .mixed:
            return UIColor.systemOrange
        case .unknown:
            return UIColor.systemGray
        }
    }
}
