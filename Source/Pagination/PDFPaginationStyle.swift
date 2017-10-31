//
//  PDFPagination.swift
//  TPPDF
//
//  Created by Philip Niedertscheider on 13/06/2017.
//
//

/**
  Use predefined pagination styles or create a custom one, using `.CustomNumberFormat` or `.CustomClosure`.
 
  Enums using a template String as parameter will replace the first instance of `%@` with the index and the second one with the total amount of pages.
 */
public enum PDFPaginationStyle: TPJSONSerializable {
    
    /**
     Default format, concats current page and total pages with a dash.
     
     e.g. Converts page 1 of 3 to **"1 - 3"**
     */
    case `default`
    
    /**
      Returns pagination in roman numerals.
     
      - Parameter template: Template `String`, instances of `%@` will be replaced.
     */
    case roman(template: String)
    
    case customNumberFormat(template: String, formatter: NumberFormatter)
    case customClosure(PDFPaginationClosure)
    
    /**
     Creates formatted pagination string.
     
     - parameter page: `Int` - Current page
     - parameter total: `Int` - Total amount of pages.
     
     - returns: Formatted `String`
     */
    public func format(page: Int, total: Int) -> String {
        switch self {
        case .default:
            return String(format: "%@ - %@", String(page), String(total))
        case .roman(let template):
            let romanIndex = toRomanNumerals(number: page)
            let romanMax = toRomanNumerals(number: total)
            
            return String(format: template, romanIndex, romanMax)
        case .customNumberFormat(let template, let formatter):
            let indexString = formatter.string(from: page as NSNumber) ?? "Formatting error!"
            let maxString = formatter.string(from: total as NSNumber) ?? "Formatting error!"
            
            return String(format: template, indexString, maxString)
        case .customClosure(let closure):
            return closure(page, total)
        }
    }
    
    // MARK: - JSON Serialization
    
    public var JSONRepresentation: AnyObject {
        return "\(self)" as AnyObject
    }
}

/**
 Closure for custom pagination formatting.
 
 - parameter page: `Int` - Current page number
 - parameter total: `Int` - Total amount of pages
 
 - returns: Formatted pagination string
 */
public typealias PDFPaginationClosure = (_ page: Int, _ total: Int) -> String

/**
  Converts given number to a string of roman numerals.
 
  - parameter number: `Int` - Number to be converted
  - returns: `String` of roman numerals
 */
func toRomanNumerals(number: Int) -> String {
    let romanValues = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
    let arabicValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
    
    var romanValue = ""
    var startingValue = number
    
    for (index, romanChar) in romanValues.enumerated() {
        let arabicValue = arabicValues[index]
        let div = startingValue / arabicValue
        
        if div > 0 {
            for _ in 0..<div {
                romanValue += romanChar
            }
            startingValue -= arabicValue * div
        }
    }
    
    return romanValue
}