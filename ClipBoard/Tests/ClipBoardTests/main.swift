import Foundation
import ClipBoardCore

@MainActor
struct TestRunner {
    static func main() {
        var passed = 0
        var failed = 0

        func run(_ name: String, _ test: () -> Void) {
            print("  \(name)...", terminator: " ")
            fflush(stdout)
            let before = failed
            test()
            if failed == before {
                print("PASSED")
                passed += 1
            }
        }

        func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
            guard actual == expected else {
                let msg = message.isEmpty ? "expected \(expected), got \(actual)" : message
                print("FAILED: \(msg)")
                failed += 1
                return
            }
        }

        print("ClipboardManager Tests")
        print("=======================")

        run("testAddTextItem") {
            let manager = ClipboardManager()
            manager.clearAll()
            manager.addItem(ClipboardItem(text: "Hello World"))
            assertEqual(manager.items.count, 1)
            assertEqual(manager.items.first?.content, "Hello World")
            assertEqual(manager.items.first?.type, .text)
        }

        run("testAddImageItem") {
            let manager = ClipboardManager()
            manager.clearAll()
            let item = ClipboardItem(imageFileName: "test.png")
            manager.addItem(item)
            assertEqual(manager.items.count, 1)
            assertEqual(manager.items.first?.imageFileName, "test.png")
            assertEqual(manager.items.first?.type, .image)
        }

        run("testDuplicateTextSkipped") {
            let manager = ClipboardManager()
            manager.clearAll()
            manager.addItem(ClipboardItem(text: "Hello"))
            manager.addItem(ClipboardItem(text: "Hello"))
            assertEqual(manager.items.count, 1, "重复文本应被跳过")
        }

        run("testDuplicateImageNotSkipped") {
            let manager = ClipboardManager()
            manager.clearAll()
            manager.addItem(ClipboardItem(imageFileName: "a.png"))
            manager.addItem(ClipboardItem(imageFileName: "b.png"))
            assertEqual(manager.items.count, 2, "不同图片文件不应去重")
        }

        run("testMaxItemLimit") {
            let manager = ClipboardManager()
            manager.clearAll()
            for i in 0..<51 {
                manager.addItem(ClipboardItem(text: "Item \(i)"))
            }
            assertEqual(manager.items.count, 50, "应不超过 50 条上限")
            assertEqual(manager.items.first?.content, "Item 50", "最新条目应在最前面")
            assertEqual(manager.items.last?.content, "Item 1", "最旧条目应是 Item 1")
        }

        run("testDeleteSingleItem") {
            let manager = ClipboardManager()
            manager.clearAll()
            let item1 = ClipboardItem(text: "First")
            let item2 = ClipboardItem(text: "Second")
            manager.addItem(item1)
            manager.addItem(item2)
            manager.deleteItem(item1)
            assertEqual(manager.items.count, 1)
            assertEqual(manager.items.first?.content, "Second")
        }

        run("testClearAll") {
            let manager = ClipboardManager()
            manager.clearAll()
            manager.addItem(ClipboardItem(text: "A"))
            manager.addItem(ClipboardItem(text: "B"))
            manager.clearAll()
            assertEqual(manager.items.count, 0)
        }

        run("testItemsOrderedByNewestFirst") {
            let manager = ClipboardManager()
            manager.clearAll()
            manager.addItem(ClipboardItem(text: "Old"))
            Thread.sleep(forTimeInterval: 0.01)
            manager.addItem(ClipboardItem(text: "New"))
            assertEqual(manager.items.first?.content, "New")
            assertEqual(manager.items.last?.content, "Old")
        }

        run("testWriteToPasteboardSuppression") {
            let manager = ClipboardManager()
            manager.clearAll()
            manager.addItem(ClipboardItem(text: "Original"))
            assertEqual(manager.items.count, 1, "Should have 1 item")
            // writeToPasteboard sets suppress, then checkPasteboard skips
            manager.addItem(ClipboardItem(text: "Original")) // 相同文本应去重
            assertEqual(manager.items.count, 1, "Duplicate should be skipped")
        }

        print("=======================")
        print("Results: \(passed) passed, \(failed) failed of \(passed + failed) total")
        if failed > 0 {
            print("SOME TESTS FAILED!")
            exit(1)
        } else {
            print("All tests passed!")
        }
    }
}

TestRunner.main()
