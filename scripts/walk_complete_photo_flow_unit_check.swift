import Foundation

@inline(__always)
func assertTrue(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ relativePath: String) -> String {
    let data = try! Data(contentsOf: root.appendingPathComponent(relativePath))
    return String(decoding: data, as: UTF8.self)
}

let walkDetail = load("dogArea/Views/MapView/WalkDetailView.swift")
let imagePicker = load("dogArea/Views/GlobalViews/ImagePicker.swift")
let infoPlist = load("dogArea/Info.plist")
let flowDoc = load("docs/walk-complete-photo-flow-v1.md")
let checklist = load("docs/release-regression-checklist-v1.md")

assertTrue(walkDetail.contains("Text(\"사진 찍기\")"), "walk detail should expose camera capture button")
assertTrue(walkDetail.contains("UIImagePickerController.isSourceTypeAvailable(.camera)"), "walk detail should check camera availability")
assertTrue(walkDetail.contains("showPhotoLibraryPicker = true"), "walk detail should support photo-library fallback")
assertTrue(walkDetail.contains("ImagePicker(image: $capturedWalkPhoto, type: .camera)"), "walk detail should open camera picker")
assertTrue(walkDetail.contains("buildShareCardImage"), "walk detail should build overlay share card image")
assertTrue(walkDetail.contains("guard let image = buildShareCardImage()"), "walk detail save should persist overlay card image")

assertTrue(imagePicker.contains("imagePickerControllerDidCancel"), "image picker should dismiss on cancel")
assertTrue(imagePicker.contains("info[.originalImage]"), "image picker should fallback to original image when edited image is unavailable")

assertTrue(infoPlist.contains("NSPhotoLibraryAddUsageDescription"), "Info.plist should declare photo library add permission")
assertTrue(infoPlist.contains("산책 완료"), "Info.plist permission copy should include walk-complete context")

assertTrue(flowDoc.contains("사진 찍기"), "flow doc should define capture scenario")
assertTrue(flowDoc.contains("날짜/시간/넓이/포인트"), "flow doc should require overlay metrics")
assertTrue(checklist.contains("사진 찍기"), "release checklist should include camera-flow regression")

print("PASS: walk complete photo flow unit checks")
