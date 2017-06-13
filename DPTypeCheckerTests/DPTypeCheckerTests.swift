//
//  DPTypeCheckerTests.swift
//  DPTypeCheckerTests
//
//  Created by Jan Wittler on 13.06.17.
//  Copyright © 2017 Jan Wittler. All rights reserved.
//

import XCTest

class DPTypeCheckerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBasicTyping() {
        /*
         let x: Int!1 = 10
         let y = 20
         assertTypeEqual(x, Int!1)
         assertTypeEqual(y, Int!inf)
        */
        let explicitType = Type.tType(.cTBase(.int), 1)
        let explicitTypeAssignStatement = Stm.sInitExplicitType(Id("x"), explicitType, .eInt(10))
        let implicitTypeAssignStatement = Stm.sInit(Id("y"), .eInt(20))
        let explicitTypeAssert = Assertion.aTypeEqual(Id("x"), explicitType)
        let implicitTypeAssert = Assertion.aTypeEqual(Id("y"), .tTypeExponential(.cTBase(.int)))
        let program = Program.pDefs([explicitTypeAssignStatement,
                                     implicitTypeAssignStatement,
                                     Stm.sAssert(explicitTypeAssert),
                                     Stm.sAssert(implicitTypeAssert)])
        
        XCTAssertNoThrow(try typeCheck(program), "type check for basic typing failed")
    }
    
    func testPair() {
        let files = ["Pair_0.dpp", "Pair_1.dpp"]
        for file in files {
            testFile(file)
        }
    }
    
    private func testFile(_ file: String) {
        guard let path = path(forResource: file, ofType: nil) else {
            XCTFail("file for \(file) not found")
            return
        }
        guard let tree = parseFile(at: path) else {
            XCTFail("failed to parse \(file)")
            return
        }
        XCTAssertNoThrow(try typeCheck(tree), "type check of \(file) failed")
    }
    
    private func path(forResource resource: String?, ofType type: String?) -> String? {
        return Bundle(for: type(of: self)).path(forResource: resource, ofType: type)
    }
}
