//
//  PDFGenerator+Generation.swift
//  Pods
//
//  Created by Philip Niedertscheider on 05/06/2017.
//
//

extension PDFGenerator {
    
    /// MARK: - Command Rendering
    
    func renderCommand(_ container: Container, command: Command, calculatingMetrics: Bool) throws {
        switch command {
        case let .addText(text, spacing):
            try drawText(container, text: text, spacing: spacing, calculatingMetrics: calculatingMetrics)
            break
        case let .addAttributedText(text):
            try drawAttributedText(container, text: text, calculatingMetrics: calculatingMetrics)
            break
        case let .addImage(image, size, caption, sizeFit):
            try drawImage(container, image: image, size: size, caption: caption, sizeFit: sizeFit, calculatingMetrics: calculatingMetrics)
            break
        case let .addImagesInRow(images, captions, spacing):
            try drawImagesInRow(container, images: images, captions: captions, spacing: spacing, calculatingMetrics: calculatingMetrics)
            break
        case let .addSpace(space):
            if container.isHeader {
                headerHeight[container] = headerHeight[container]! + space
            } else if container.isFooter {
                footerHeight[container] = footerHeight[container]! + space
            } else {
                contentHeight += space
            }
            break
        case let .addLineSeparator(style):
            drawLineSeparator(container, style: style, calculatingMetrics: calculatingMetrics)
            break
        case let .addTable(table):
            try drawTable(container, data: table.data, alignments: table.alignments, relativeColumnWidth: table.widths, padding: CGFloat(table.padding), margin: CGFloat(table.margin), style: table.style, showHeadersOnEveryPage: table.showHeadersOnEveryPage, calculatingMetrics: calculatingMetrics)
            break
        case let .addList(list):
            try drawList(container, list: list, calculatingMetrics: calculatingMetrics)
            break
        case let .setIndentation(value):
            indentation[container.normalize] = value
            break
        case let .setOffset(value):
            setContentOffset(container, value: value)
            break
        case let .setFont(font):
            fonts[container] = font
            break
        case let .setTextColor(color):
            textColor = color
            break
        case .createNewPage():
            try generateNewPage(calculatingMetrics: calculatingMetrics)
            break
        }
    }
    
    func renderHeaderFooter(calculatingMetrics: Bool) throws {
        resetHeaderFooterHeight()
        
        if paginationContainer != .none {
            if !paginationExcludes.contains(currentPage) && currentPage >= paginationStart && currentPage <= paginationEnd {
                try renderCommand(paginationContainer, command: .addText(text: paginationStyle.format(page: currentPage, total: totalPages), lineSpacing: 1.0), calculatingMetrics: calculatingMetrics)
            }
        }
        
        for (container, command) in headerFooterCommands {
            try renderCommand(container, command: command, calculatingMetrics: calculatingMetrics)
        }
    }
    
    // MARK: - PDF Data Generation
    
    /**
     Generates PDF data and returns it
     
     - parameter progress:  Optional closure for progress handling. Parameter is between 0.0 and 1.0
     - returns:             PDF Data
     
     - throws:              TPPDFError

     */
    open func generatePDFdata(_ progress: ((CGFloat) -> ())? = nil) throws -> Data {
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, pageBounds, generateDocumentInfo())
        try generatePDFContext(progress: progress)
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
    
    /**
     Generates PDF data and writes it to a temporary file.
     
     - parameter fileName:  Name of temporary file.
     - parameter progress:  Optional closure for progress handling. Parameter is between 0.0 and 1.0
     - returns:             URL to temporary file.
     
     - throws:              TPPDFError
     */
    open func generatePDFfile(_ fileName: String, progress: ((CGFloat) -> ())? = nil) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension("pdf")
        
        UIGraphicsBeginPDFContextToFile(url.path, pageBounds, generateDocumentInfo())
        try generatePDFContext(progress: progress)
        UIGraphicsEndPDFContext()
        
        return url;
    }
    
    /**
     Generate PDF Context from commands
     
     - parameter progress:  Optional closure for progress handling. Parameter is between 0.0 and 1.0
     
     - throws: TPPDFError
     */
    fileprivate func generatePDFContext(progress: ((CGFloat) -> ())?) throws {
        UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
        
        // Extract header & footer commands
        headerFooterCommands = commands.filter { return $0.0.isFooter || $0.0.isHeader }
        let contentCommands = commands.filter { return !$0.0.isFooter && !$0.0.isHeader }
        
        // Split header & footer commands
        let footers = commands.filter { return $0.0.isFooter }
        let headers = commands.filter { return $0.0.isHeader }
        
        // Only add space between content and footer if footer commands exist.
        if footers.count == 0 {
            footerSpace = 0
        }
        
        // Only add space between content and header if header commands exist.
        if headers.count == 0 {
            headerSpace = 0
        }
        
        // Progress equals the number of commands run. Each command is called once for calculations and second for rendering.
        var progressIndex: CGFloat = 0.0;
        let progressMax: CGFloat = CGFloat(contentCommands.count * 2)
        
        // Only calculate render header & footer metrics if page has content.
        if contentCommands.count > 0 {
            try renderHeaderFooter(calculatingMetrics: true)
        }
        
        // Dry run all commands. This won't render anything but instad calculate all the frames.
        for (container, command) in contentCommands {
            try autoreleasepool {
                try renderCommand(container, command: command, calculatingMetrics: true)
                progressIndex = progressIndex + 1;
                progress?(progressIndex / progressMax)
            }
        }
        // Save calculated page count from reseting
        totalPages = currentPage
        
        // Reset all changes made by metrics calculation to generator
        resetGenerator()
        
        // Only render header & footer if page has content.
        if contentCommands.count > 0 {
            try renderHeaderFooter(calculatingMetrics: false)
        }
        
        // Render each command
        for (container, command) in contentCommands {
            try autoreleasepool {
                try renderCommand(container, command: command, calculatingMetrics: false)
                progressIndex = progressIndex + 1;
                progress?(progressIndex / progressMax)
            }
        }
    }
}