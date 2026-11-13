import SwiftUI
import ContactsUI

/// Sistem seçicisi yalnız kullanıcının seçtiği kişiyi verir; tüm rehber okunmaz.
struct RehberSecici: UIViewControllerRepresentable {
    let sec: (String) -> Void
    let vazgec: () -> Void

    func makeCoordinator() -> Koordinator { Koordinator(sec: sec, vazgec: vazgec) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForSelectionOfContact = NSPredicate(value: true)
        return picker
    }
    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}

    final class Koordinator: NSObject, CNContactPickerDelegate {
        let sec: (String) -> Void
        let vazgec: () -> Void
        init(sec: @escaping (String) -> Void, vazgec: @escaping () -> Void) { self.sec = sec; self.vazgec = vazgec }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            var ad = CNContactFormatter.string(from: contact, style: .fullName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if ad.isEmpty, contact.isKeyAvailable(CNContactOrganizationNameKey) { ad = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines) }
            sec(ad)
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { vazgec() }
    }
}
