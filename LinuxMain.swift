import XCTest

import AutoGraphTests
import QueryBuilderTests

var tests = [XCTestCaseEntry]()
tests += AutoGraphTests.__allTests()
tests += QueryBuilderTests.__allTests()

XCTMain(tests)
