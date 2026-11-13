import SwiftUI
import ContactsUI

/// UIKit seçicisi kendi penceresini kapatır; satış formunun SwiftUI sheet'ine dokunmaz.
struct RehberSecici: UIViewControllerRepresentable {
    @Binding var acik: Bool
    let sec: (String) -> Void

    func makeUIViewController(context: Context) -> RehberSunucusu { RehberSunucusu() }
    func updateUIViewController(_ controller: RehberSunucusu, context: Context) {
        controller.sec = { ad in acik = false; sec(ad) }
        controller.vazgec = { acik = false }
        controller.acik = acik
        controller.sunmayiDene()
    }
}

final class RehberSunucusu: UIViewController, CNContactPickerDelegate {
    var acik = false
    var sec: (String) -> Void = { _ in }
    var vazgec: () -> Void = {}
    private var secici: CNContactPickerViewController?

    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .clear }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); sunmayiDene() }

    func sunmayiDene() {
        guard acik, secici == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.acik, self.secici == nil, self.view.window != nil,
                  self.presentedViewController == nil else { return }
            let picker = CNContactPickerViewController()
            picker.delegate = self
            picker.predicateForSelectionOfContact = NSPredicate(value: true)
            self.secici = picker
            self.present(picker, animated: true)
        }
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        var ad = CNContactFormatter.string(from: contact, style: .fullName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if ad.isEmpty, contact.isKeyAvailable(CNContactOrganizationNameKey) {
            ad = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Seçici kendi sunumunu kapatır; üstteki satış formuna dismiss gönderilmez.
        acik = false
        secici = nil
        sec(ad)
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        acik = false
        secici = nil
        vazgec()
    }
}
